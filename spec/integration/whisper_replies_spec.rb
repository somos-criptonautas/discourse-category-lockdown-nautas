# frozen_string_literal: true
require "rails_helper"

RSpec.describe "CategoryLockdown whisper replies" do
  fab!(:subscribers) { Fabricate(:group) }
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:op) { Fabricate(:post, topic: topic) }
  fab!(:subscriber) { Fabricate(:user, groups: [subscribers]) }
  fab!(:outsider) { Fabricate(:user) }

  before do
    SiteSetting.category_lockdown_enabled = true
    SiteSetting.whispers_allowed_groups = subscribers.id.to_s
  end

  def reply_as(user, raw: "a support question")
    PostCreator.create!(user, topic_id: topic.id, raw: raw, skip_validations: true)
  end

  context "when the category has whisper replies enabled" do
    before do
      category.custom_fields["lockdown_whisper_replies"] = "t"
      category.save_custom_fields(true)
      topic.reload
    end

    it "creates replies as whispers" do
      expect(reply_as(subscriber).post_type).to eq(Post.types[:whisper])
    end

    it "leaves the first post of a new topic public" do
      new_topic =
        PostCreator.create!(
          subscriber,
          category: category.id,
          title: "A brand new lesson here",
          raw: "the lesson body",
        )
      expect(new_topic.post_type).to eq(Post.types[:regular])
    end

    it "does not raise the public post count" do
      expect { reply_as(subscriber) }.not_to change { topic.reload.posts_count }
      expect(topic.reload.highest_post_number).to eq(1)
    end

    it "hides replies from users who cannot whisper" do
      reply = reply_as(subscriber)
      expect(Guardian.new(outsider).can_see_post?(reply)).to eq(false)
      expect(Guardian.new(nil).can_see_post?(reply)).to eq(false)
      expect(Guardian.new(subscriber).can_see_post?(reply)).to eq(true)
    end

    it "keeps replies out of search for outsiders but not for subscribers" do
      SearchIndexer.enable
      reply_as(subscriber, raw: "pineapple casserole recipe")
      expect(Search.execute("pineapple", guardian: Guardian.new(outsider)).posts).to be_empty
      expect(Search.execute("pineapple", guardian: Guardian.new(subscriber)).posts).to be_present
    end

    it "reports the real reply count to subscribers only" do
      2.times { reply_as(subscriber) }
      topic.reload

      as_subscriber =
        TopicListItemSerializer.new(topic, scope: Guardian.new(subscriber), root: false)
      as_outsider = TopicListItemSerializer.new(topic, scope: Guardian.new(outsider), root: false)

      expect(as_subscriber.posts_count).to eq(3)
      expect(as_outsider.posts_count).to eq(1)
    end

    it "tells visitors how many replies they are not being shown" do
      2.times { reply_as(subscriber) }

      as_outsider =
        TopicViewSerializer.new(
          TopicView.new(topic, outsider),
          scope: Guardian.new(outsider),
          root: false,
        )
      expect(as_outsider.lockdown_hidden_reply_count).to eq(2)

      as_subscriber =
        TopicViewSerializer.new(
          TopicView.new(topic, subscriber),
          scope: Guardian.new(subscriber),
          root: false,
        )
      expect(as_subscriber.include_lockdown_hidden_reply_count?).to eq(false)
    end
  end

  context "when the category does not have it enabled" do
    it "leaves replies as regular posts" do
      expect(reply_as(subscriber).post_type).to eq(Post.types[:regular])
    end
  end
end
