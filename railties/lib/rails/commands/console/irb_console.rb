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
        executor = Rails.application.executor
        executor.run!(reset: true) if executor.active?
        Rails.application.reloader.reload!
      end
    end

    IRB::HelperMethod.register(:helper, ControllerHelper)
    IRB::HelperMethod.register(:controller, ControllerInstance)
    IRB::HelperMethod.register(:new_session, NewSession)
    IRB::HelperMethod.register(:app, AppInstance)
    IRB::HelperMethod.register(:reload!, ReloadHelper)

    class IRBConsole
      TIPS = [
        '"app" opens an ActionDispatch::Integration::Session for the app',
        '"helper" gives access to ApplicationController\'s helper methods',
        '"controller" gives you a new ApplicationController instance',
        '"reload!" reloads the application',
        '"--sandbox" rolls back database changes when the console exits',
        '"_" holds the value of the last evaluated expression',
        '"source_location" shows where a method was defined, e.g. method(:reload!).source_location',
      ].freeze

      LOGO = %w[⠀⢀⠀⢡⣶⣿⠟⡛⠢ ⠠⠀⣰⣿⣿⠁⠄⠀⠀ ⠶⢠⣿⣿⣿⠰⠆⠀⠀ ⠶⢸⣿⣿⣿⡄⠰⠆⠀].freeze

      def initialize(app, options = {})
        @app = app
        @options = options

        require "irb"
        require "irb/completion"
      end

      def name
        "IRB"
      end

      def start
        IRB.setup(nil)
        # CLI --no-banner wins over IRB defaults / .irbrc.
        IRB.conf[:SHOW_BANNER] = false if @options[:banner] == false

        if !Rails.env.local? && !ENV.key?("IRB_USE_AUTOCOMPLETE")
          IRB.conf[:USE_AUTOCOMPLETE] = false
        end

        env = colorized_short_env
        prompt_prefix = "%N(#{env})"
        # Respect user's configured irb name.
        IRB.conf[:IRB_NAME] = @app.name if IRB.conf[:IRB_NAME] == "irb"

        IRB.conf[:PROMPT][:RAILS_PROMPT] = {
          PROMPT_I: "#{prompt_prefix}:%03n> ",
          PROMPT_S: "#{prompt_prefix}:%03n%l ",
          PROMPT_C: "#{prompt_prefix}:%03n* ",
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
        show_startup_banner
        IRB::Irb.new.run(IRB.conf)
      end

      def show_startup_banner
        return $stderr.puts(Rails::Console.startup_lines(@app.sandbox)) unless IRB.conf[:SHOW_BANNER]

        logo_lines = unicode_logo
        tip_line = show_tips? ? "TIP: #{colorize_tip(TIPS.sample)}" : ""
        info_lines = [
          "#{IRB::Color.colorize('Rails', [:BOLD])} v#{Rails.version} - Ruby #{RUBY_VERSION}  (#{colorized_env})",
          tip_line,
          IRB::Color.colorize(short_rails_root, [:CYAN]),
          Rails::Console::HELP_HINT,
        ]

        output = if logo_lines
          logo_lines.zip(info_lines).map { |logo, info| "#{IRB::Color.colorize(logo.to_s, [:RED, :BOLD])}  #{info}" }.join("\n")
        else
          info_lines.join("\n")
        end

        $stderr.puts
        $stderr.puts output
        $stderr.puts IRB::Color.colorize("\nSandbox mode: changes rolled back on exit", [:YELLOW]) if @app.sandbox
        $stderr.puts
      end

      def unicode_logo
        ($stderr.external_encoding || Encoding.default_external) == Encoding::UTF_8 ? LOGO : nil
      end

      def show_tips?
        ENV["RAILS_TIPS"] != "false"
      end

      def colorize_tip(tip)
        tip.gsub(/"[^"]*"/) { |match| IRB::Color.colorize(match, [:YELLOW]) }
      end

      def short_rails_root
        root = Rails.root.to_s
        home = ENV["HOME"]
        home && (root == home || root.start_with?("#{home}/")) ? "~#{root[home.size..]}" : root
      end

      def colorized_short_env
        IRB::Color.colorize(short_env, [env_color])
      end

      def short_env
        case Rails.env
        when "development"
          "dev"
        when "test"
          "test"
        when "production"
          "prod"
        else
          Rails.env
        end
      end

      def colorized_env
        IRB::Color.colorize(Rails.env, [env_color])
      end

      def env_color
        case Rails.env
        when "development", "test"
          :BLUE
        when "production"
          :RED
        else
          :MAGENTA
        end
      end
    end
  end
end
