# frozen_string_literal: true

require "rails/command/environment_argument"

module Rails
  module Command
    class RunnerCommand < Base # :nodoc:
      include EnvironmentArgument

      class_option :skip_executor, type: :boolean, aliases: "-w", desc: "Don't wrap with Rails Executor", default: false

      no_commands do
        def help(command_name = nil, *)
          super
          if command_name == "runner"
            say ""
            say self.class.class_usage
          end
        end
      end

      desc "runner [<'Some.ruby(code)'> | <filename.rb> | -]",
        "Run Ruby code in the context of your application"
      def perform(code_or_file = nil, *command_argv)
        unless code_or_file
          help
          exit 1
        end

        boot_application!
        Rails.application.load_runner

        ARGV.replace(command_argv)

        wrap_with_executor = !options[:skip_executor]
        if code_or_file == "-"
          conditional_executor(wrap_with_executor, source: "application.runner.railties") do
            eval($stdin.read, TOPLEVEL_BINDING, "stdin")
          end
        elsif File.exist?(code_or_file)
          expanded_file_path = File.expand_path code_or_file
          $0 = expanded_file_path
          conditional_executor(wrap_with_executor, source: "application.runner.railties") do
            Kernel.load expanded_file_path
          end
        else
          begin
            conditional_executor(wrap_with_executor, source: "application.runner.railties") do
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

      private
        def conditional_executor(enabled, **args, &block)
          if enabled
            Rails.application.executor.wrap(**args, &block)
          else
            yield
          end
        end

        def looks_like_a_file_path?(code_or_file)
          code_or_file.ends_with?(".rb")
        end
    end
  end
end
