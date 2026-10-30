# frozen_string_literal: true

# Search builds its post scope in SQL and never calls Guardian#can_see_post?,
# so the plugin's Guardian and TopicView enforcement does not reach it. Its only
# category filter is "NOT categories.read_restricted", which a lockdown category
# is not, so every locked post would otherwise be returned to anyone searching.
#
# posts_query is private and has no supported override point. The arguments are
# passed straight through so a change to its signature cannot silently drop a
# filter here.

module ::CategoryLockdown::SearchExtension
  def posts_query(*args, **kwargs)
    ::CategoryLockdown.exclude_locked(super, guardian)
  end
end
