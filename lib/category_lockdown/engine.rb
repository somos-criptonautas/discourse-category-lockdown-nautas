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
