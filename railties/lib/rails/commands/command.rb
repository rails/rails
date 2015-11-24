module Rails
  module Commands
    class Command
      attr_reader :argv

      def initialize(argv)
        @argv = argv

        @option_parser = build_option_parser
        @options = {}
      end

      def run(task_name)
        command_name = Command.name_for(task_name)

        parse_options_for(command_name)
        @option_parser.parse! @argv

        if command_instance = command_instance_for(command_name)
          command_instance.public_send(command_name)
        else
          puts @option_parser
        end
      end

      def tasks
        public_instance_methods.map { |method| method.gsub('_', ':') }
      end

      def self.options_for(command_name, &options_to_parse)
        @@command_options[command_name] = options_to_parse
      end

      def self.rake_delegate(*task_names)
        task_names.each do |task_name|
          define_method(name_for(task_name)) do
            system "rake #{task_name}"
          end
        end
      end

      def self.name_for(task_name)
        task_name.gsub(':', '_')
      end

      def self.set_banner(command_name, banner)
        options_for(command_name) { |opts, _| opts.banner banner }
      end

      private
        @@commands = []
        @@command_options = {}

        def parse_options_for(command_name)
          @@command_options.fetch(command_name.to_sym, -> {}).call(@option_parser, @options)
        rescue ArgumentError
          false
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

        def command_instance_for(command_name)
          klass = @@commands.find do |command|
            command_instance_methods = command.public_instance_methods
            command_instance_methods.include?(command_name.to_sym)
          end

          klass.new(@argv)
        end
    end
  end
end
