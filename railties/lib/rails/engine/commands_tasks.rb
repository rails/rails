require 'rails/commands/rake_proxy'
require 'rails/commands/commands_tasks'

module Rails
  class Engine
    class CommandsTasks < CommandsTasks # :nodoc:
      include Rails::RakeProxy

      attr_reader :argv

      # Some commands are not supported in engines,
      # since they're infrequently used, and should be run in the application
      UNSUPPORTED_COMMANDS = ['new', 'plugin new']

      APPLICATION_WHITELIST = %w(console server runner version dbconsole help)

      ENGINE_WHITELIST = %w(generate destroy test)

      def run_command!(command)
        command = parse_command(command)

        if ENGINE_WHITELIST.include?(command)
          send(command)
        elsif APPLICATION_WHITELIST.include?(command)
          run_in_application(command)
        else
          run_rake_task(command)
        end
      end

      def run_in_application(command)
        while !Pathname.pwd.root?
          if File.exists?(File.expand_path('config/application.rb', Dir.pwd))
            Object.const_set(:APP_PATH, File.expand_path('config/application', Dir.pwd))
            send(command)
            break
          else
            Dir.chdir("..")
          end
        end
      end

      private

        def generate_or_destroy(command)
          load_generators
          require_command!(command)
        end

        def load_generators
          require 'rails/generators'
          require ENGINE_PATH

          engine = ::Rails::Engine.find(ENGINE_ROOT)
          Rails::Generators.namespace = engine.railtie_namespace
          engine.load_generators
        end

        def main_commands
          super.reject { |command| UNSUPPORTED_COMMANDS.include? command }
        end

        def additional_commands
          super.reject { |command| UNSUPPORTED_COMMANDS.include? command }
        end
    end
  end
end
