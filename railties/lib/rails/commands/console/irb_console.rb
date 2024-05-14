# frozen_string_literal: true

require "irb/helper_method"
require "irb/command"

module Rails
  class Console
    class RailsHelperBase < IRB::HelperMethod::Base
      include ConsoleMethods
    end

    class ControllerHelper < RailsHelperBase
      description "Gets the helper methods available to the controller."

      # This method assumes an +ApplicationController+ exists, and that it extends ActionController::Base.
      def execute
        ApplicationController.helpers
      end
    end

    class ControllerInstance < RailsHelperBase
      description "Gets a new instance of a controller object."

      # This method assumes an +ApplicationController+ exists, and that it extends ActionController::Base.
      def execute
        @controller ||= ApplicationController.new
      end
    end

    class NewSession < RailsHelperBase
      description "Create a new session. If a block is given, the new session will be yielded to the block before being returned."

      def execute(*)
        app = Rails.application
        session = ActionDispatch::Integration::Session.new(app)

        # This makes app.url_for and app.foo_path available in the console
        session.extend(app.routes.url_helpers)
        session.extend(app.routes.mounted_helpers)

        session
      end
    end

    class AppInstance < NewSession
      description "Reference the global 'app' instance, created on demand. To recreate the instance, pass a non-false value as the parameter."

      def execute(create = false)
        @app_integration_instance = nil if create
        @app_integration_instance ||= super
      end
    end

    class Reloader < IRB::Command::Base
      include ConsoleMethods

      category "Rails console"
      description "Reloads the environment."

      def execute(*)
        puts "Reloading..."
        Rails.application.reloader.reload!
      end
    end

    IRB::HelperMethod.register(:helper, ControllerHelper)
    IRB::HelperMethod.register(:controller, ControllerInstance)
    IRB::HelperMethod.register(:new_session, NewSession)
    IRB::HelperMethod.register(:app, AppInstance)
    IRB::Command.register(:reload!, Reloader)

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
        app_name = @app.class.module_parent_name.underscore.dasherize
        prompt_prefix = "%N(#{env})"
        IRB.conf[:IRB_NAME] = app_name

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

        # Because some users/libs use Rails::ConsoleMethods to extend Rails console,
        # we still include it for backward compatibility.
        IRB::ExtendCommandBundle.include ConsoleMethods

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
