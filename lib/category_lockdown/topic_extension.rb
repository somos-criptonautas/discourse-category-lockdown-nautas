# frozen_string_literal: true

# Both select topics by category security only and then show part of the first
# post: the composer's similar-topics blurb, and the digest email's excerpts
# (Post.for_mailing_list builds the digest's popular posts on for_digest too).

module ::CategoryLockdown::TopicExtension
  def similar_to(title, raw, user = nil)
    topics = super
    return topics if !topics.is_a?(::ActiveRecord::Relation)

    ::CategoryLockdown.exclude_locked(topics, ::Guardian.new(user))
  end

  def for_digest(user, since, opts = nil)
    ::CategoryLockdown.exclude_locked(super, ::Guardian.new(user))
  end
end
