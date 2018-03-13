# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "active_storage/engine"

Bundler.require(*Rails.groups)

module DummyApi
  class Application < Rails::Application
    config.load_defaults 5.2

    config.active_storage.service = :local
    config.api_only = true
  end
end
