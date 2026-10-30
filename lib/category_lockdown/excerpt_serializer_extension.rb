# frozen_string_literal: true

# Topic list items and suggested topics carry the first post's excerpt when the
# topic is pinned or always_include_topic_excerpts is on.

module ::CategoryLockdown::ExcerptSerializerExtension
  def include_excerpt?
    return super if !SiteSetting.category_lockdown_enabled
    super && !::CategoryLockdown.is_locked(scope, object)
  end
end
