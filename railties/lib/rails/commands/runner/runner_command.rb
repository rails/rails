# frozen_string_literal: true

require "rails/command/environment_argument"

module Rails
  module Command
    class RunnerCommand < Base # :nodoc:
      include EnvironmentArgument

      self.environment_desc = "The environment for the runner to operate under (test/development/production)"

      no_commands do
        def help
          super
          say self.class.desc
        end
      end

      def self.banner(*)
        "#{super} [<'Some.ruby(code)'> | <filename.rb> | -]"
      end

      def perform(code_or_file = nil, *command_argv)
        extract_environment_option_from_argument

        unless code_or_file
          help
          exit 1
        end

        ENV["RAILS_ENV"] = options[:environment]

        require_application_and_environment!
        Rails.application.load_runner

        ARGV.replace(command_argv)

        if code_or_file == "-"
          Rails.application.executor.wrap(source: "application.runner.railties") do
            eval($stdin.read, TOPLEVEL_BINDING, "stdin")
          end
        elsif File.exist?(code_or_file)
          expanded_file_path = File.expand_path code_or_file
          $0 = expanded_file_path
          Rails.application.executor.wrap(source: "application.runner.railties") do
            Kernel.load expanded_file_path
          end
        else
          begin
            Rails.application.executor.wrap(source: "application.runner.railties") do
              eval(code_or_file, TOPLEVEL_BINDING, __FILE__, __LINE__)
            end
          rescue SyntaxError, NameError => e
            if looks_like_a_file_path?(code_or_file)
              error "The file #{code_or_file} could not be found, please check and try again."
              error "Run '#{self.class.executable} -h' for help."
            else
              error "Please specify a valid ruby command or the path of a script to run."
              error "Run '#{self.class.executable} -h' for help."
              error ""
              error e
            end

            exit 1
          end
        end
      end

      def looks_like_a_file_path?(code_or_file)
        code_or_file.ends_with?(".rb")
      end
    end
  end
end
