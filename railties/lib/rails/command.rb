require "active_support"
require "active_support/dependencies/autoload"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/hash/transform_values"

require "thor"

module Rails
  module Command
    extend ActiveSupport::Autoload

    autoload :Behavior
    autoload :Base

    include Behavior

    HELP_MAPPINGS = %w(-h -? --help)

    class << self
      def hidden_commands # :nodoc:
        @hidden_commands ||= []
      end

      def environment # :nodoc:
        ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
      end

      # Receives a namespace, arguments and the behavior to invoke the command.
      def invoke(full_namespace, args = [], **config)
        namespace = full_namespace = full_namespace.to_s

        if char = namespace =~ /:(\w+)$/
          command_name, namespace = $1, namespace.slice(0, char)
        else
          command_name = namespace
        end

        command_name, namespace = "help", "help" if command_name.blank? || HELP_MAPPINGS.include?(command_name)
        command_name, namespace = "version", "version" if %w( -v --version ).include?(command_name)

        command = find_by_namespace(namespace, command_name)
        if command && command.all_commands[command_name]
          command.perform(command_name, args, config)
        else
          find_by_namespace("rake").perform(full_namespace, args, config)
        end
      end

      # Rails finds namespaces similar to Thor, it only adds one rule:
      #
      # Command names must end with "_command.rb". This is required because Rails
      # looks in load paths and loads the command just before it's going to be used.
      #
      #   find_by_namespace :webrat, :rails, :integration
      #
      # Will search for the following commands:
      #
      #   "rails:webrat", "webrat:integration", "webrat"
      #
      # Notice that "rails:commands:webrat" could be loaded as well, what
      # Rails looks for is the first and last parts of the namespace.
      def find_by_namespace(namespace, command_name = nil) # :nodoc:
        lookups = [ namespace ]
        lookups << "#{namespace}:#{command_name}" if command_name
        lookups.concat lookups.map { |lookup| "rails:#{lookup}" }

        lookup(lookups)

        namespaces = subclasses.index_by(&:namespace)
        namespaces[(lookups & namespaces.keys).first]
      end

      # Returns the root of the Rails engine or app running the command.
      def root
        if defined?(ENGINE_ROOT)
          Pathname.new(ENGINE_ROOT)
        elsif defined?(APP_PATH)
          Pathname.new(File.expand_path("../..", APP_PATH))
        end
      end

      def print_commands # :nodoc:
        sorted_groups.each { |b, n| print_list(b, n) }
      end

      def sorted_groups # :nodoc:
        lookup!

        groups = (subclasses - hidden_commands).group_by { |c| c.namespace.split(":").first }
        groups.transform_values! { |commands| commands.flat_map(&:printing_commands).sort }

        rails = groups.delete("rails")
        [[ "rails", rails ]] + groups.sort.to_a
      end

      private
        def command_type # :doc:
          @command_type ||= "command"
        end

        def lookup_paths # :doc:
          @lookup_paths ||= %w( rails/commands commands )
        end

        def file_lookup_paths # :doc:
          @file_lookup_paths ||= [ "{#{lookup_paths.join(',')}}", "**", "*_command.rb" ]
        end
    end
  end
end
