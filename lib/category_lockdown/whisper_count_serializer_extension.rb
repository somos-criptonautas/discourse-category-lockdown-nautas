# frozen_string_literal: true

# Whispers deliberately leave topics.posts_count alone, which is what keeps the
# public reply count at zero. That single column serves both audiences, so
# readers who can see the whispers have to be given the real count here.
# highest_staff_post_number counts whispers and is already on the topic row, so
# this costs no extra query. It is a high water mark: it over-counts if posts
# are later deleted from the topic.

module ::CategoryLockdown::WhisperCountSerializerExtension
  def posts_count
    return super if !scope&.user&.whisperer?
    return super if !::CategoryLockdown.whisper_replies?(object.category)

    [object.highest_staff_post_number.to_i, super].max
  end
end
