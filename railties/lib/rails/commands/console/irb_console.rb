# frozen_string_literal: true

require "irb/helper_method"
require "irb/command"

module Rails
  class Console
    class RailsHelperBase < IRB::HelperMethod::Base
    end

    class ControllerHelper < RailsHelperBase
      description "Gets helper methods available to ApplicationController."

      # This method assumes an +ApplicationController+ exists, and that it extends ActionController::Base.
      def execute
        ApplicationController.helpers
      end
    end

    class ControllerInstance < RailsHelperBase
      description "Gets a new instance of ApplicationController."

      # This method assumes an +ApplicationController+ exists, and that it extends ActionController::Base.
      def execute
        @controller ||= ApplicationController.new
      end
    end

    class NewSession < RailsHelperBase
      description "[Deprecated] Please use `app(true)` instead."

      def execute(*)
        app = Rails.application
        app.reload_routes_unless_loaded
        session = ActionDispatch::Integration::Session.new(app)

        # This makes app.url_for and app.foo_path available in the console
        session.extend(app.routes.url_helpers)
        session.extend(app.routes.mounted_helpers)

        session
      end
    end

    class AppInstance < NewSession
      description "Creates a new ActionDispatch::Integration::Session and memoizes it. Use `app(true)` to create a new instance."

      def execute(create = false)
        @app_integration_instance = nil if create
        @app_integration_instance ||= super
      end
    end

    class ReloadHelper < RailsHelperBase
      description "Reloads the Rails application."

      def execute
        puts "Reloading..."
        Rails.application.reloader.reload!
      end
    end

    IRB::HelperMethod.register(:helper, ControllerHelper)
    IRB::HelperMethod.register(:controller, ControllerInstance)
    IRB::HelperMethod.register(:new_session, NewSession)
    IRB::HelperMethod.register(:app, AppInstance)
    IRB::HelperMethod.register(:reload!, ReloadHelper)

    class IRBConsole
      def initialize(app)
        @app = app

        require "irb"
        require "irb/completion"
      end

      def name
        "IRB"
      end

      def start
        IRB.setup(nil)

        if !Rails.env.local? && !ENV.key?("IRB_USE_AUTOCOMPLETE")
          IRB.conf[:USE_AUTOCOMPLETE] = false
        end

        env = colorized_env
        prompt_prefix = "%N(#{env})"
        # Respect user's configured irb name.
        IRB.conf[:IRB_NAME] = @app.name if IRB.conf[:IRB_NAME] == "irb"

        IRB.conf[:PROMPT][:RAILS_PROMPT] = {
          PROMPT_I: "#{prompt_prefix}> ",
          PROMPT_S: "#{prompt_prefix}%l ",
          PROMPT_C: "#{prompt_prefix}* ",
          RETURN: "=> %s\n"
        }

        if current_filter = IRB.conf[:BACKTRACE_FILTER]
          IRB.conf[:BACKTRACE_FILTER] = -> (backtrace) do
            backtrace = current_filter.call(backtrace)
            Rails.backtrace_cleaner.filter(backtrace)
          end
        else
          IRB.conf[:BACKTRACE_FILTER] = -> (backtrace) do
            Rails.backtrace_cleaner.filter(backtrace)
          end
        end

        # Respect user's choice of prompt mode.
        IRB.conf[:PROMPT_MODE] = :RAILS_PROMPT if IRB.conf[:PROMPT_MODE] == :DEFAULT
        IRB::Irb.new.run(IRB.conf)
      end

      def colorized_env
        case Rails.env
        when "development"
          IRB::Color.colorize("dev", [:BLUE])
        when "test"
          IRB::Color.colorize("test", [:BLUE])
        when "production"
          IRB::Color.colorize("prod", [:RED])
        else
          Rails.env
        end
      end
    end
  end
end
