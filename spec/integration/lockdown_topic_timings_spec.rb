# frozen_string_literal: true
require "rails_helper"

# Read state feeds course progress, so a locked topic must not collect any from
# someone who cannot read it.
RSpec.describe "CategoryLockdown topic timings", type: :request do
  fab!(:allowed_group) { Fabricate(:group) }
  fab!(:category)
  fab!(:member) { Fabricate(:user, groups: [allowed_group]) }
  fab!(:outsider) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:lesson) { Fabricate(:post, topic: topic) }

  before do
    SiteSetting.category_lockdown_enabled = true
    category.custom_fields["lockdown_enabled"] = "t"
    category.custom_fields["lockdown_allowed_groups"] = allowed_group.name
    category.save_custom_fields(true)
  end

  def post_timings
    post "/topics/timings.json",
         params: {
           topic_id: topic.id,
           topic_time: 1000,
           timings: {
             lesson.post_number => 1000,
           },
         }
  end

  def read_state(user)
    [
      TopicUser.where(user: user, topic: topic).where("last_read_post_number >= 1").exists?,
      PostTiming.where(user: user, topic: topic).exists?,
    ]
  end

  it "records nothing for a non-member and answers as core does" do
    sign_in(outsider)
    post_timings
    expect(response.status).to eq(200)
    expect(response.body).to be_empty
    expect(read_state(outsider)).to eq([false, false])

    SiteSetting.category_lockdown_enabled = false
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
