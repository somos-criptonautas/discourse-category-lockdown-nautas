# frozen_string_literal: true

# The /posts.json and /posts.rss firehose selects the most recent posts across
# the site, filtered only by Category.secured. A lockdown category is readable,
# so its posts appear there for anyone, including anonymous visitors.

module ::CategoryLockdown::LatestPostsQueryExtension
  def public_posts(*args, **kwargs)
    ::CategoryLockdown.exclude_locked(super, guardian)
  end
end
