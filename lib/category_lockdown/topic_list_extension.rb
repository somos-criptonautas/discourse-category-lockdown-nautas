# frozen_string_literal: true

# Topic lists stay public, titles included, but two things in them are content.
# The RSS feeds print each topic's whole first post, so locked topics are left out
# of feeds. The excerpt shown for pinned topics (or every topic, with
# always_include_topic_excerpts or in the .md list) is blanked in memory, the
# same way core swaps in localized titles before rendering a list.

module ::CategoryLockdown::TopicListExtension
  def render(*args, **kwargs, &block)
    if @topic_list && request.format.rss?
      locked_ids = ::CategoryLockdown.locked_category_ids(guardian)
      @topic_list.topics.reject! { |topic| locked_ids.include?(topic.category_id) }
    end
    super
  end

  def respond_with_list(list)
    locked_ids = ::CategoryLockdown.locked_category_ids(guardian)
    list.topics.each { |topic| topic.excerpt = nil if locked_ids.include?(topic.category_id) }
    super
  end
end
