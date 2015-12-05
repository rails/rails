module Rails
  module Commands
    class Command
      attr_reader :argv

      def initialize(argv = '')
        @argv = argv

        @option_parser = build_option_parser
        @options = {}
      end

      def run(task_name)
        command_name = self.class.command_name_for(task_name)

        parse_options_for(command_name)
        @option_parser.parse! @argv

        if command_instance = command_for(command_name)
          command_instance.public_send(command_name)
        else
          puts @option_parser
        end
      end

      def self.options_for(command_name, &options_to_parse)
        @@command_options[command_name] = options_to_parse
      end

      def self.set_banner(command_name, banner)
        options_for(command_name) { |opts, _| opts.banner = banner }
      end

      def exists?(task_name) # :nodoc:
        command_name = self.class.command_name_for(task_name)
        !command_for(command_name).nil?
      end

      private
        @@commands = []
        @@command_options = {}

        def parse_options_for(command_name)
          @@command_options.fetch(command_name, -> {}).call(@option_parser, @options)
        end

        def build_option_parser
          OptionParser.new do |opts|
            opts.on('-h', '--help', 'Show this help.') do
              puts opts
              exit
            end
          end
        end

        def self.inherited(command)
          @@commands << command
        end

        def self.command_name_for(task_name)
          task_name.gsub(':', '_').to_sym
        end

        def command_for(command_name)
          klass = @@commands.find do |command|
            command_instance_methods = command.public_instance_methods
            command_instance_methods.include?(command_name)
          end

          if klass
            klass.new(@argv)
          else
            nil
          end
        end
    end
  end
end
