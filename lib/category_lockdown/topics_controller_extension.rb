# frozen_string_literal: true
require "request_store"

module ::CategoryLockdown::TopicsControllerExtension
  def show
    ::RequestStore.store[:is_crawler] = use_crawler_layout?
    ::RequestStore.store[:lockdown_request_ip] = request.remote_ip
    super
  end
end
