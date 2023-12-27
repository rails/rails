# frozen_string_literal: true

require "active_support/core_ext/object/deep_dup"
require "active_support/core_ext/array/wrap"
require "useragent"

module ActionDispatch # :nodoc:
  # = Browser Guard
  # Rails.application.configure do
  #   config.browser_guard do |guard|
  #     guard.require_at_least :chrome, 110
  #   end

  #   # Handler get's called for all browsers that don't match the requirement, e.g. for reporting or logging
  #   config.browser_guard_error_handler = ->(request) { Rails.logger.info("#{request.user_agent} is unsupported!") }
  # end
  class BrowserGuard
    module Request
      BROWSER_GUARD = "action_dispatch.browser_guard"
      BROWSER_GUARD_ERROR_HANDLER = "action_dispatch.browser_guard_error_handler"

      def browser_guard
        get_header(BROWSER_GUARD)
      end

      def browser_guard=(config)
        set_header(BROWSER_GUARD, config)
      end

      def browser_guard_error_handler
        get_header(BROWSER_GUARD_ERROR_HANDLER)
      end

      def browser_guard_error_handler=(handler)
        set_header(BROWSER_GUARD_ERROR_HANDLER, handler)
      end
    end

    Browser = Struct.new(:browser, :version)

    class Middleware
      def initialize(app)
        @app = app
      end

      def call(env)
        request = ActionDispatch::Request.new env
        @browser_guard_config = request.browser_guard

        user_agent = UserAgent.parse(request.user_agent)
        if app_supports?(user_agent)
          @app.call(env)
        else
          request.browser_guard_error_handler.call(request)
          body = File.read(Rails.public_path.join("browser_support.html"))
          [
            403,
            {
              Rack::CONTENT_LENGTH => body.bytesize.to_s,
            },
            [body]
          ]
        end
      end

      private
        def app_supports?(user_agent)
          if min_version = @browser_guard_config.min_versions_for_browsers[user_agent.browser]
            user_agent >= Browser.new(user_agent.browser, min_version)
          else
            # we did not find any config for the current browser, therefore we pass
            # I think this could also be a configuration.
            true
          end
        end
    end

    attr_reader :min_versions_for_browsers
    def initialize
      @min_versions_for_browsers = {} # by default every browser in every version is valid
      yield self if block_given?
    end

    SYMBOL_TO_BROWSER_MAPPING = {
      chrome: "Chrome",
      safari: "Safari",
      firefox: "Firefox",
      edge: "Edge",
      internet_explorer: "Internet Explorer",
      opera: "Opera",
      vivaldi: "Vivaldi"
    }

    def require_at_least(vendor, version)
      browser_name = SYMBOL_TO_BROWSER_MAPPING.fetch(vendor)
      @min_versions_for_browsers[browser_name] = version.to_s
    end
  end
end
