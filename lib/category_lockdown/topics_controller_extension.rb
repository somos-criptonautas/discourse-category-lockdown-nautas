# frozen_string_literal: true
require "request_store"

module ::CategoryLockdown::TopicsControllerExtension
  def show
    # The crawler layout is also served for ?print and _escaped_fragment_, which
    # any browser can request, so only the User-Agent may claim the exemption.
    ::RequestStore.store[:is_crawler] = ::CrawlerDetection.crawler?(
      request.user_agent,
      request.headers["HTTP_VIA"],
    )
    ::RequestStore.store[:lockdown_request_ip] = request.remote_ip
    super
  end

  # Returns excerpts of any posts in the topic by id, checking only that the
  # topic is visible.
  def excerpts
    topic = ::Topic.with_deleted.find_by(id: params[:topic_id])
    if SiteSetting.category_lockdown_enabled && topic &&
         ::CategoryLockdown.is_locked(guardian, topic)
      raise ::CategoryLockdown::NoAccessLocked.new
    end
    super
  end
end
