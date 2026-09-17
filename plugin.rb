# frozen_string_literal: true
# name: discourse-category-lockdown-nautas
# about: Restrict a category to specified groups, redirecting everyone else to the category description topic
# version: 1.3.0
# authors: Pavilion, Criptonautas
# url: https://github.com/somos-criptonautas/discourse-category-lockdown-nautas

enabled_site_setting :category_lockdown_enabled

register_asset "stylesheets/common/category-lockdown.scss"

module ::CategoryLockdown
  PLUGIN_NAME = "category-lockdown"
end

require_relative "lib/category_lockdown/engine"

after_initialize do
  register_html_builder("server:before-head-close-crawler") do |controller|
    ::CategoryLockdown::CrawlerHtmlBuilder.perform(controller)
  end

  rescue_from(::CategoryLockdown::NoAccessLocked) do
    opts = { include_ember: true }
    topic_id = params["topic_id"] || params["id"]
    topic_id ||= params["topic"] # if coming from discourse-docs plugin
    topic = Topic.find_by(id: topic_id.to_i) if topic_id

    redirect_target =
      if topic&.category && guardian.can_see_category?(topic.category)
        about = topic.category.topic
        if about && guardian.can_see_topic?(about)
          about.relative_url
        else
          topic.category.url
        end
      end
    redirect_target ||= path("/")

    if request.format.json?
      render_json_dump({ error: "Payment Required", redirect_url: redirect_target }, status: 402)
    else
      redirect_to redirect_target
    end
  end

  ::TopicsController.prepend ::CategoryLockdown::TopicsControllerExtension
  ::TopicView.prepend ::CategoryLockdown::TopicViewExtension
  ::Guardian.prepend ::CategoryLockdown::PostGuardianExtension
  ::PostCreator.singleton_class.prepend ::CategoryLockdown::PostCreatorExtension
  ::TopicListItemSerializer.prepend ::CategoryLockdown::WhisperCountSerializerExtension

  register_category_custom_field_type("lockdown_whisper_replies", :boolean)
  ::Site.preloaded_category_custom_fields << "lockdown_whisper_replies"

  # The composer mirrors the replied-to post's whisper state, so it needs to know
  # which categories whisper by default in order to keep the reply UI ordinary.
  add_to_serializer(
    :basic_category,
    :lockdown_whisper_replies,
    include_condition: -> { SiteSetting.category_lockdown_enabled },
  ) { ::CategoryLockdown.whisper_replies?(object) }

  ::TopicList.preloaded_custom_fields << "lockdown_enabled"
  ::TopicList.preloaded_custom_fields << "lockdown_allowed_groups"

  add_to_serializer(
    :topic_list_item,
    :is_locked_down,
    include_condition: -> { SiteSetting.category_lockdown_enabled },
  ) { ::CategoryLockdown.is_locked(scope, object) }

  # How many replies a visitor is not being shown. The count is not content, so
  # revealing it is what makes the teaser worth reading; the bodies stay hidden.
  # Only serialized to readers who cannot see the whispers, so it never has to be
  # reconciled with what a subscriber already sees in the stream.
  add_to_serializer(
    :topic_view,
    :lockdown_hidden_reply_count,
    include_condition: -> do
      SiteSetting.category_lockdown_enabled && !scope.user&.whisperer? &&
        ::CategoryLockdown.whisper_replies?(object.topic&.category)
    end,
  ) do
    ::Post.where(topic_id: object.topic.id, post_type: Post.types[:whisper], hidden: false).count
  end
end
