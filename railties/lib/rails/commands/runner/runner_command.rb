module Rails
  module Command
    class RunnerCommand < Base # :nodoc:
      class_option :environment, aliases: "-e", type: :string,
        default: Rails::Command.environment.dup,
        desc: "The environment for the runner to operate under (test/development/production)"

      no_commands do
        def help
          super
          puts self.class.desc
        end
      end

      def self.banner(*)
        "#{super} [<'Some.ruby(code)'> | <filename.rb>]"
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

        if File.exist?(code_or_file)
          $0 = code_or_file
          Kernel.load code_or_file
        else
          begin
            eval(code_or_file, binding, __FILE__, __LINE__)
          rescue SyntaxError, NameError => error
            $stderr.puts "Please specify a valid ruby command or the path of a script to run."
            $stderr.puts "Run '#{self.class.executable} -h' for help."
            $stderr.puts
            $stderr.puts error
            exit 1
          end
        end
      end
    end
  end
end
