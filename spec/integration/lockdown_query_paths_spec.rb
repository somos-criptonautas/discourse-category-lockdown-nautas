# frozen_string_literal: true
require "rails_helper"

# Search and the latest-posts firehose build their scopes in SQL and never call
# Guardian#can_see_post?, so the plugin's other enforcement points do not cover
# them. These are the regression tests for that: if a Discourse upgrade moves
# the seams these hook into, this fails instead of leaking silently.
RSpec.describe "CategoryLockdown query paths" do
  fab!(:allowed_group) { Fabricate(:group) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:member) { Fabricate(:user, groups: [allowed_group]) }
  fab!(:outsider) { Fabricate(:user) }

  let!(:post) { Fabricate(:post, topic: topic, raw: "aardvark casserole instructions") }

  before do
    SiteSetting.category_lockdown_enabled = true
    category.custom_fields["lockdown_enabled"] = "t"
    category.custom_fields["lockdown_allowed_groups"] = allowed_group.name
    category.save_custom_fields(true)
    SearchIndexer.enable
    SearchIndexer.index(post, force: true)
  end

  it "keeps locked posts out of search for outsiders and anonymous visitors" do
    expect(Search.execute("aardvark", guardian: Guardian.new(outsider)).posts).to be_empty
    expect(Search.execute("aardvark", guardian: Guardian.new).posts).to be_empty
  end

  it "still finds them for members and admins" do
    expect(Search.execute("aardvark", guardian: Guardian.new(member)).posts).to be_present
    expect(
      Search.execute("aardvark", guardian: Guardian.new(Fabricate(:admin))).posts,
    ).to be_present
  end

  it "keeps locked posts out of the latest posts firehose" do
    outsider_posts =
      LatestPostsQuery.new(user: outsider, guardian: Guardian.new(outsider)).public_posts
    expect(outsider_posts).not_to include(post)

    anon_posts = LatestPostsQuery.new(user: nil, guardian: Guardian.new).public_posts
    expect(anon_posts).not_to include(post)

    member_posts = LatestPostsQuery.new(user: member, guardian: Guardian.new(member)).public_posts
    expect(member_posts).to include(post)
  end

  it "leaves unlocked categories alone" do
    other = Fabricate(:topic)
    other_post = Fabricate(:post, topic: other, raw: "aardvark public notes")
    SearchIndexer.index(other_post, force: true)

    expect(Search.execute("aardvark", guardian: Guardian.new(outsider)).posts).to contain_exactly(
      other_post,
    )
  end
end
