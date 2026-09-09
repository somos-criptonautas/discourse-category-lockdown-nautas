# frozen_string_literal: true

# Replies in a "whisper replies" category are created as whispers, so only
# members of SiteSetting.whispers_allowed_groups can read them. The first post
# stays a regular post and remains public.
#
# The hook wraps PostCreator.before_create_tasks rather than adding a
# before_create callback, because that method reads post_type to decide whether
# to bump the topic's public counters (Topic.next_post_number). A plugin
# callback would run after it and the counters would already be wrong.

module ::CategoryLockdown
  def self.whisper_replies?(category)
    return false if !SiteSetting.category_lockdown_enabled
    boolean_custom_field(category, "lockdown_whisper_replies")
  end

  def self.whisper_reply?(post)
    return false if post.post_type != Post.types[:regular]

    topic = post.topic
    return false if topic.blank? || topic.private_message?

    # The topic's own first post has nothing above it yet.
    return false if topic.highest_post_number.to_i < 1

    whisper_replies?(topic.category)
  end

  module PostCreatorExtension
    def before_create_tasks(post)
      post.post_type = Post.types[:whisper] if ::CategoryLockdown.whisper_reply?(post)
      super
    end
  end

  # Whispers deliberately leave topics.posts_count alone, which is what keeps the
  # public reply count at zero. That single column serves both audiences, so
  # readers who can see the whispers have to be given the real count here.
  # highest_staff_post_number counts whispers and is already on the topic row.
  module WhisperCountSerializerExtension
    def posts_count
      return super if !scope&.user&.whisperer?
      return super if !::CategoryLockdown.whisper_replies?(object.category)

      [object.highest_staff_post_number.to_i, super].max
    end
  end
end
