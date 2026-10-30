# frozen_string_literal: true

# A link to a topic on its own line is cooked into an onebox holding the linked
# post's excerpt. Core checks only that the topic is visible. The onebox is then
# stored in the linking post and shown to everyone who can read that post, so the
# lock is checked as an anonymous visitor, not as the author.

module ::CategoryLockdown::OneboxerExtension
  def local_topic_html(url, route, opts)
    if SiteSetting.category_lockdown_enabled
      topic = ::Topic.find_by(id: route[:id] || route[:topic_id])
      return if topic && ::CategoryLockdown.is_locked(::Guardian.new, topic)
    end
    super
  end
end
