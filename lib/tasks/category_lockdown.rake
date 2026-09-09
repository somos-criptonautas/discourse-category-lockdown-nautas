# frozen_string_literal: true

# Replies posted before "keep replies private" was turned on are still regular
# posts and stay publicly readable. Convert them, then let core recompute the
# per-topic high water marks so the public and whisperer counts both settle.
#
#   rake category_lockdown:whisper_existing_replies[123]
#   rake category_lockdown:whisper_existing_replies[123,dry_run]
desc "Convert existing replies in a category to whispers"
task "category_lockdown:whisper_existing_replies", %i[category_id mode] => :environment do |_, args|
  category = Category.find(args[:category_id])
  dry_run = args[:mode] == "dry_run"

  posts =
    Post
      .joins(:topic)
      .where(topics: { category_id: category.id })
      .where(post_type: Post.types[:regular])
      .where("posts.post_number > 1")

  puts "#{posts.count} replies in ##{category.slug} to convert#{dry_run ? " (dry run)" : ""}"
  next if dry_run

  topic_ids = posts.distinct.pluck(:topic_id)
  posts.update_all(post_type: Post.types[:whisper])
  topic_ids.each { |topic_id| Topic.reset_highest(topic_id) }

  puts "Converted. Recomputed #{topic_ids.size} topics."
end
