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

  class NoAccessLocked < StandardError
  end
end
