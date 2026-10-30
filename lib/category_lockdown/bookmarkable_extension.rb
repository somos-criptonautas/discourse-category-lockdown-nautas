# frozen_string_literal: true

# The bookmarks list serializes each bookmarked post's cooked HTML and excerpt.
# Creating a bookmark checks can_see_post?, but a bookmark made while the user
# was still a member keeps listing the content after they leave the group.

module ::CategoryLockdown::BookmarkableExtension
  def list_query(user, guardian)
    ::CategoryLockdown.exclude_locked(super, guardian)
  end
end
