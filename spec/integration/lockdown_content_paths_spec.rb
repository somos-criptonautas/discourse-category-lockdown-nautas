# frozen_string_literal: true
require "rails_helper"

# Core paths that show part of a post after checking only that the topic is
# visible, which a locked topic is. Each test also checks that the path shows
# the content once the lock is off, so a core change that empties the path
# cannot make the test pass for the wrong reason.
RSpec.describe "CategoryLockdown content paths", type: :request do
  fab!(:allowed_group) { Fabricate(:group) }
  fab!(:category)
  fab!(:member) { Fabricate(:user, groups: [allowed_group]) }
  fab!(:outsider) { Fabricate(:user) }
  fab!(:topic) do
    Fabricate(
      :topic,
      category: category,
      title: "Aardvark casserole lesson for subscribers",
      excerpt: "lesson summary excerpt",
      created_at: 1.day.ago,
    )
  end
  fab!(:post) { Fabricate(:post, topic: topic, user: member, raw: "casserole instructions here") }

  let(:body_text) { "casserole instructions" }

  before do
    SiteSetting.category_lockdown_enabled = true
    category.custom_fields["lockdown_enabled"] = "t"
    category.custom_fields["lockdown_allowed_groups"] = allowed_group.name
    category.save_custom_fields(true)
  end

  def unlock
    SiteSetting.category_lockdown_enabled = false
  end

  it "leaves locked topics out of the topic list RSS feeds" do
    get "/latest.rss"
    expect(response.status).to eq(200)
    expect(response.body).not_to include(body_text)

    get "/c/#{category.slug}/#{category.id}.rss"
    expect(response.status).to eq(200)
    expect(response.body).not_to include(body_text)

    unlock
    get "/latest.rss"
    expect(response.body).to include(body_text)
  end

  it "drops the excerpt of locked topics from topic lists" do
    SiteSetting.always_include_topic_excerpts = true

    get "/latest.json"
    item = response.parsed_body["topic_list"]["topics"].find { |t| t["id"] == topic.id }
    expect(item).to be_present
    expect(item["excerpt"]).to be_nil

    unlock
    get "/latest.json"
    item = response.parsed_body["topic_list"]["topics"].find { |t| t["id"] == topic.id }
    expect(item["excerpt"]).to eq("lesson summary excerpt")
  end

  it "drops the pinned excerpt from the crawler topic list" do
    topic.update!(pinned_at: Time.zone.now, pinned_globally: true, pinned_until: 1.month.from_now)

    get "/latest", headers: { "HTTP_USER_AGENT" => "Googlebot" }
    expect(response.status).to eq(200)
    expect(response.body).to include(topic.title)
    expect(response.body).not_to include("lesson summary excerpt")

    unlock
    get "/latest", headers: { "HTTP_USER_AGENT" => "Googlebot" }
    expect(response.body).to include("lesson summary excerpt")
  end

  it "keeps locked posts out of group activity and its feed" do
    get "/g/#{allowed_group.name}/posts.json"
    expect(response.status).to eq(200)
    expect(response.body).not_to include(body_text)

    get "/g/#{allowed_group.name}/posts.rss"
    expect(response.status).to eq(200)
    expect(response.body).not_to include(body_text)

    unlock
    get "/g/#{allowed_group.name}/posts.json"
    expect(response.body).to include(body_text)
  end

  it "keeps locked content out of the bookmarks of someone who left the group" do
    Fabricate(:topic_user, user: outsider, topic: topic)
    topic_bookmark = Fabricate(:bookmark, user: outsider, bookmarkable: topic)
    post_bookmark = Fabricate(:bookmark, user: outsider, bookmarkable: post)
    guardian = Guardian.new(outsider)

    expect(TopicBookmarkable.list_query(outsider, guardian)).not_to include(topic_bookmark)
    expect(PostBookmarkable.list_query(outsider, guardian)).not_to include(post_bookmark)

    unlock
    expect(TopicBookmarkable.list_query(outsider, guardian)).to include(topic_bookmark)
    expect(PostBookmarkable.list_query(outsider, guardian)).to include(post_bookmark)
  end

  it "doesn't onebox the content of a locked topic" do
    onebox = Oneboxer.preview(topic.url, user_id: member.id, invalidate_oneboxes: true)
    expect(onebox).not_to include(body_text)

    unlock
    onebox = Oneboxer.preview(topic.url, user_id: member.id, invalidate_oneboxes: true)
    expect(onebox).to include(body_text)
  end

  it "refuses post excerpts of a locked topic" do
    get "/t/#{topic.id}/excerpts.json", params: { post_ids: [post.id] }
    expect(response.status).to eq(402)

    sign_in(member)
    get "/t/#{topic.id}/excerpts.json", params: { post_ids: [post.id] }
    expect(response.status).to eq(200)
    expect(response.body).to include(body_text)
  end

  it "keeps locked topics out of similar topics" do
    SearchIndexer.enable
    SearchIndexer.index(topic, force: true)

    expect(Topic.similar_to(topic.title, "", outsider)).not_to include(topic)
    expect(Topic.similar_to(topic.title, "", member)).to include(topic)
  end

  it "keeps locked topics out of digests" do
    reader = Fabricate(:user, groups: [allowed_group])

    expect(Topic.for_digest(outsider, 1.week.ago, include_tl0: true)).not_to include(topic)
    expect(Topic.for_digest(reader, 1.week.ago, include_tl0: true)).to include(topic)
  end

  describe "POST /topics/timings" do
    def post_timings(target = topic)
      post "/topics/timings.json",
           params: {
             topic_id: target.id,
             topic_time: 1000,
             timings: {
               1 => 1000,
             },
           }
    end

    def read_state(user, target = topic)
      [
        TopicUser.where(user: user, topic: target).where("last_read_post_number >= 1").exists?,
        PostTiming.where(user: user, topic: target).exists?,
      ]
    end

    it "records nothing for a non-member and answers as core does" do
      sign_in(outsider)
      post_timings
      expect(response.status).to eq(200)
      expect(response.body).to be_empty
      expect(read_state(outsider)).to eq([false, false])

      unlock
      post_timings
      expect(read_state(outsider)).to eq([true, true])
    end

    it "records for a member" do
      sign_in(member)
      post_timings
      expect(response.status).to eq(200)
      expect(read_state(member)).to eq([true, true])
    end

    it "records for staff" do
      [Fabricate(:admin), Fabricate(:moderator)].each do |staff|
        sign_in(staff)
        post_timings
        expect(response.status).to eq(200)
        expect(read_state(staff)).to eq([true, true])
      end
    end

    it "keeps core's 404 for a locked topic the user cannot see" do
      category.set_permissions(allowed_group => :full)
      category.save!

      sign_in(outsider)
      post_timings
      expect(response.status).to eq(404)
    end
  end
end
