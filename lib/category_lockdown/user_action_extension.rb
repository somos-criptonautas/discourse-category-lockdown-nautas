# frozen_string_literal: true

# User activity streams and profile stats are built with a SQL builder and the
# same "NOT c.read_restricted" category filter as search, so a locked category's
# posts would show up in the author's public activity. filter_categories is the
# one place both the stream and the stats queries pass through, and both alias
# categories as c.

module ::CategoryLockdown::UserActionExtension
  def filter_categories(builder, guardian)
    scoped = super

    locked_ids = ::CategoryLockdown.locked_category_ids(guardian)
    return scoped if locked_ids.empty?

    scoped.where(
      "(c.id IS NULL OR c.id NOT IN (:lockdown_locked_ids))",
      lockdown_locked_ids: locked_ids,
    )
  end
end
