# frozen_string_literal: true
require "request_store"

module CategoryLockdown::TopicViewExtension
  def check_and_raise_exceptions(skip_staff_action)
    super
    return if ::CategoryLockdown.crawler_exempt?
    if SiteSetting.category_lockdown_enabled && CategoryLockdown.is_locked(@guardian, @topic)
      raise ::CategoryLockdown::NoAccessLocked.new
    end
  end
end
