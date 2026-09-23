# frozen_string_literal: true

# The /posts.json and /posts.rss firehose selects the most recent posts across
# the site, filtered only by Category.secured. A lockdown category is readable,
# so its posts appear there for anyone, including anonymous visitors.

module ::CategoryLockdown::LatestPostsQueryExtension
  def public_posts(*args, **kwargs)
    posts = super

    locked_ids = ::CategoryLockdown.locked_category_ids(guardian)
    return posts if locked_ids.empty?

    posts.where("topics.category_id IS NULL OR topics.category_id NOT IN (?)", locked_ids)
  end
end
