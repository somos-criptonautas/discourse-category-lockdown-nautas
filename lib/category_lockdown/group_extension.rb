# frozen_string_literal: true

# A group's posts and mentions pages (/g/:name/posts.json, .rss and the mentions
# equivalents) filter by Guardian#filter_allowed_categories, which only knows
# read_restricted categories. Both lists pass through this one method.

module ::CategoryLockdown::GroupExtension
  def filter_posts_for_guardian(result, guardian, opts = nil)
    ::CategoryLockdown.exclude_locked(super, guardian)
  end
end
