# frozen_string_literal: true

module Rails
  module Command
    class RunnerCommand < Base # :nodoc:
      class_option :environment, aliases: "-e", type: :string,
        default: Rails::Command.environment.dup,
        desc: "The environment for the runner to operate under (test/development/production)"

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
        unless code_or_file
          help
          exit 1
        end

        ENV["RAILS_ENV"] = options[:environment]

        require_application_and_environment!
        Rails.application.load_runner

        ARGV.replace(command_argv)

        if code_or_file == "-"
          eval($stdin.read, TOPLEVEL_BINDING, "stdin")
        elsif File.exist?(code_or_file)
          $0 = code_or_file
          Kernel.load code_or_file
        else
          begin
            eval(code_or_file, TOPLEVEL_BINDING, __FILE__, __LINE__)
          rescue SyntaxError, NameError => e
            error "Please specify a valid ruby command or the path of a script to run."
            error "Run '#{self.class.executable} -h' for help."
            error ""
            error e
            exit 1
          end
        end
      end
    end
  end
end
