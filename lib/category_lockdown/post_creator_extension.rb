# frozen_string_literal: true

# Replies in a "keep replies private" category are created as whispers, so only
# members of SiteSetting.whispers_allowed_groups can read them. The first post
# stays a regular post and remains public.
#
# This wraps PostCreator.before_create_tasks rather than adding a before_create
# callback on Post, because that method reads post_type to decide whether to
# bump the topic's public counters (Topic.next_post_number). A plugin callback
# is appended after core's and would run once the counters are already wrong.
# It is also the reason the :before_create_post event is unsuitable: PostCreator
# skips that event entirely when skip_validations is set.

module ::CategoryLockdown::PostCreatorExtension
  def before_create_tasks(post)
    post.post_type = Post.types[:whisper] if ::CategoryLockdown.whisper_reply?(post)
    super
  end
end
