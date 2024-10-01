# frozen_string_literal: true

# :markup: markdown

module ActionController # :nodoc:
  module AllowBrowser
    extend ActiveSupport::Concern

    module ClassMethods
      # Specify the browser versions that will be allowed to access all actions (or
      # some, as limited by `only:` or `except:`). Only browsers matched in the hash
      # or named set passed to `versions:` will be blocked if they're below the
      # versions specified. This means that all other browsers, as well as agents that
      # aren't reporting a user-agent header, will be allowed access.
      #
      # A browser that's blocked will by default be served the file in
      # public/406-unsupported-browser.html with a HTTP status code of "406 Not
      # Acceptable".
      #
      # In addition to specifically named browser versions, you can also pass
      # `:modern` as the set to restrict support to browsers natively supporting webp
      # images, web push, badges, import maps, CSS nesting, and CSS :has. This
      # includes Safari 17.2+, Chrome 120+, Firefox 121+, Opera 106+.
      #
      # You can use https://caniuse.com to check for browser versions supporting the
      # features you use.
      #
      # You can use `ActiveSupport::Notifications` to subscribe to events of browsers
      # being blocked using the `browser_block.action_controller` event name.
      #
      # Examples:
      #
      #     class ApplicationController < ActionController::Base
      #       # Allow only browsers natively supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has
      #       allow_browser versions: :modern
      #     end
      #
      #     class ApplicationController < ActionController::Base
      #       # All versions of Chrome and Opera will be allowed, but no versions of "internet explorer" (ie). Safari needs to be 16.4+ and Firefox 121+.
      #       allow_browser versions: { safari: 16.4, firefox: 121, ie: false }
      #     end
      #
      #     class MessagesController < ApplicationController
      #       # In addition to the browsers blocked by ApplicationController, also block Opera below 104 and Chrome below 119 for the show action.
      #       allow_browser versions: { opera: 104, chrome: 119 }, only: :show
      #     end
      def allow_browser(versions:, block: -> { render file: Rails.root.join("public/406-unsupported-browser.html"), layout: false, status: :not_acceptable }, **options)
        before_action -> { allow_browser(versions: versions, block: block) }, **options
      end
    end

    private
      def allow_browser(versions:, block:)
        require "useragent"

        if BrowserBlocker.new(request, versions: versions).blocked?
          ActiveSupport::Notifications.instrument("browser_block.action_controller", request: request, versions: versions) do
            instance_exec(&block)
          end
        end
      end

      class BrowserBlocker # :nodoc:
        SETS = {
          modern: { safari: 17.2, chrome: 120, firefox: 121, opera: 106, ie: false }
        }

        attr_reader :request, :versions

        def initialize(request, versions:)
          @request, @versions = request, versions
        end

        def blocked?
          user_agent_version_reported? && unsupported_browser?
        end

        private
          def parsed_user_agent
            @parsed_user_agent ||= UserAgent.parse(request.user_agent)
          end

          def user_agent_version_reported?
            request.user_agent.present? && parsed_user_agent.version.to_s.present?
          end

          def unsupported_browser?
            version_guarded_browser? && version_below_minimum_required? && !bot?
          end

          def version_guarded_browser?
            minimum_browser_version_for_browser != nil
          end

          def bot?
            parsed_user_agent.bot?
          end

          def version_below_minimum_required?
            if minimum_browser_version_for_browser
              parsed_user_agent.version < UserAgent::Version.new(minimum_browser_version_for_browser.to_s)
            else
              true
            end
          end

          def minimum_browser_version_for_browser
            expanded_versions[normalized_browser_name]
          end

          def expanded_versions
            @expanded_versions ||= (SETS[versions] || versions).with_indifferent_access
          end

          def normalized_browser_name
            case name = parsed_user_agent.browser.downcase
            when "internet explorer" then "ie"
            else name
            end
          end
      end
  end
end
