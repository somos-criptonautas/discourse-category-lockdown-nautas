# frozen_string_literal: true
module ::CategoryLockdown
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace CategoryLockdown
    config.autoload_paths << File.join(config.root, "lib")
  end

  def self.is_locked(guardian, topic)
    return false if guardian.is_admin?

    # The category's About topic holds the description visitors are
    # redirected to, so it must stay viewable (otherwise the redirect loops).
    return false if topic&.category&.topic_id == topic&.id

    return false if !boolean_custom_field(topic.category, "lockdown_enabled")

    allowed_groups = topic.category&.custom_fields&.[]("lockdown_allowed_groups")
    allowed_groups = "" if allowed_groups.nil?
    allowed_groups = allowed_groups.split(",")

    in_allowed_groups = guardian&.user&.groups&.where(name: allowed_groups)&.exists?

    !in_allowed_groups
  end

  # Category custom fields arrive as "t"/"true" from the category form and as a
  # real boolean from the seeded/API path.
  def self.boolean_custom_field(category, name)
    ["true", "t", true].include?(category&.custom_fields&.[](name))
  end

  def self.whisper_replies?(category)
    return false if !SiteSetting.category_lockdown_enabled
    boolean_custom_field(category, "lockdown_whisper_replies")
  end

  # Called while the post is still unsaved, so post_number is not assigned yet.
  # The topic's own first post is the one with nothing above it.
  def self.whisper_reply?(post)
    return false if post.post_type != Post.types[:regular]

    topic = post.topic
    return false if topic.blank? || topic.private_message?
    return false if topic.highest_post_number.to_i < 1

    whisper_replies?(topic.category)
  end

  # Categories this guardian may not read, for the query paths that never call
  # can_see_post?. Search and the latest-posts firehose build SQL directly and
  # filter only on categories.read_restricted, which a lockdown category is not
  # - that is the whole point of it - so their posts would otherwise be readable
  # by anyone. Fails closed: with no user, every locked category is excluded.
  #
  # Slightly broader than is_locked, which exempts a category's own description
  # topic. Excluding that topic from search too is the safe direction.
  def self.locked_category_ids(guardian)
    return [] if !SiteSetting.category_lockdown_enabled
    return [] if guardian&.is_admin?

    locked_ids =
      ::CategoryCustomField.where(name: "lockdown_enabled", value: %w[true t]).pluck(:category_id)
    return [] if locked_ids.empty?

    group_names = guardian&.user&.groups&.pluck(:name) || []
    return locked_ids if group_names.empty?

    permitted_ids =
      ::CategoryCustomField
        .where(name: "lockdown_allowed_groups", category_id: locked_ids)
        .pluck(:category_id, :value)
        .select { |_id, value| (value.to_s.split(",") & group_names).any? }
        .map(&:first)

    locked_ids - permitted_ids
  end

  # The crawler exemption deliberately serves locked content, so that search
  # engines can index it behind the paywall metadata. use_crawler_layout? matches
  # the User-Agent string and nothing else, which anyone can send, so on its own
  # this exemption is advisory. Turning on the verified-ip setting additionally
  # requires the request to come from an ASN in core's crawler_asns setting -
  # which means crawler_asns must be populated, or nothing qualifies.
  def self.crawler_exempt?
    return false if !SiteSetting.category_lockdown_allow_crawlers
    return false if !::RequestStore.store[:is_crawler]
    return true if !SiteSetting.category_lockdown_crawler_require_verified_ip

    ::CrawlerDetection.crawler_ip?(::RequestStore.store[:lockdown_request_ip])
  end

  MAX_TEASER_PARTICIPANTS = 5

  # Distinct authors of the hidden replies, capped, plus how many there are in
  # total so the teaser can say "and N others". Two small queries on a topic
  # page, run only for readers who are being shown the teaser.
  def self.hidden_reply_participants(topic)
    user_ids =
      ::Post
        .where(topic_id: topic.id, post_type: Post.types[:whisper], hidden: false)
        .distinct
        .pluck(:user_id)
        .compact

    users = ::User.real.where(id: user_ids.first(MAX_TEASER_PARTICIPANTS)).order(:id)

    {
      total: user_ids.size,
      users:
        users.map { |user| { username: user.username, avatar_template: user.avatar_template } },
    }
  end

  class NoAccessLocked < StandardError
  end
end
