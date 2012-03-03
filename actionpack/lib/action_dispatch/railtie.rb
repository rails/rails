require "action_dispatch"

module ActionDispatch
  class Railtie < Rails::Railtie
    config.action_dispatch = ActiveSupport::OrderedOptions.new
    config.action_dispatch.x_sendfile_header = nil
    config.action_dispatch.ip_spoofing_check = true
    config.action_dispatch.show_exceptions = true
    config.action_dispatch.best_standards_support = true
    config.action_dispatch.tld_length = 1
    config.action_dispatch.ignore_accept_header = false
    config.action_dispatch.rescue_templates = { }
    config.action_dispatch.rescue_responses = { }
    config.action_dispatch.default_charset = nil

    config.action_dispatch.rack_cache = {
      :metastore => "rails:/",
      :entitystore => "rails:/",
      :verbose => false
    }

    initializer "action_dispatch.configure" do |app|
      ActionDispatch::Http::URL.tld_length = app.config.action_dispatch.tld_length
      ActionDispatch::Request.ignore_accept_header = app.config.action_dispatch.ignore_accept_header
      ActionDispatch::Response.default_charset = app.config.action_dispatch.default_charset || app.config.encoding

      ActionDispatch::ExceptionWrapper.rescue_responses.merge!(config.action_dispatch.rescue_responses)
      ActionDispatch::ExceptionWrapper.rescue_templates.merge!(config.action_dispatch.rescue_templates)

      config.action_dispatch.always_write_cookie = Rails.env.development? if config.action_dispatch.always_write_cookie.nil?
      ActionDispatch::Cookies::CookieJar.always_write_cookie = config.action_dispatch.always_write_cookie
    end
  end
end
