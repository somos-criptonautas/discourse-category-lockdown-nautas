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

  # Records read state, which feeds course progress, after checking only that the
  # topic is visible. Answers as core does so the client's read tracker doesn't
  # retry or show an error. The visibility check keeps core's 404 for hidden topics.
  def timings
    return super if !SiteSetting.category_lockdown_enabled || guardian.is_staff?
    topic = find_visible_topic_from_topic_id
    return render(body: nil) if ::CategoryLockdown.is_locked(guardian, topic)
    super
  end
end
