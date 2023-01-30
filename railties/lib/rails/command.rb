# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/object/blank"
require "rails/deprecator"

require "thor"

module Rails
  module Command
    extend ActiveSupport::Autoload

    autoload :Behavior
    autoload :Base

    class CorrectableNameError < StandardError # :nodoc:
      attr_reader :name

      def initialize(message, name, alternatives)
        @name = name
        @alternatives = alternatives
        super(message)
      end

      if !Exception.method_defined?(:detailed_message)
        def detailed_message(...)
          message
        end
      end

      if defined?(DidYouMean::Correctable) && defined?(DidYouMean::SpellChecker)
        include DidYouMean::Correctable

        def corrections
          @corrections ||= DidYouMean::SpellChecker.new(dictionary: @alternatives).correct(name)
        end
      end
    end

    class UnrecognizedCommandError < CorrectableNameError # :nodoc:
      def initialize(name)
        super("Unrecognized command #{name.inspect}", name, Command.printing_commands.map(&:first))
      end
    end

    include Behavior

    HELP_MAPPINGS = %w(-h -? --help).to_set
    VERSION_MAPPINGS = %w(-v --version).to_set

    class << self
      def hidden_commands # :nodoc:
        @hidden_commands ||= []
      end

      def environment # :nodoc:
        ENV["RAILS_ENV"].presence || ENV["RACK_ENV"].presence || "development"
      end

      # Receives a namespace, arguments, and the behavior to invoke the command.
      def invoke(full_namespace, args = [], **config)
        full_namespace = full_namespace.to_s

        namespace, command_name = split_namespace(full_namespace)

        args = ["--help"] if rails_new_with_no_path?(args)

        original_argv = ARGV.dup
        ARGV.replace(args)

        command = find_by_namespace(namespace, command_name)
        if command && command.all_commands[command_name]
          command.perform(command_name, args, config)
        else
          args = ["--describe", full_namespace] if HELP_MAPPINGS.include?(args[0])
          find_by_namespace("rake").perform(full_namespace, args, config)
        end
      rescue UnrecognizedCommandError => error
        puts error.detailed_message
        exit(1)
      ensure
        ARGV.replace(original_argv)
      end

      # Rails finds namespaces similar to Thor, it only adds one rule:
      #
      # Command names must end with "_command.rb". This is required because Rails
      # looks in load paths and loads the command just before it's going to be used.
      #
      #   find_by_namespace :webrat, :integration
      #
      # Will search for the following commands:
      #
      #   "webrat", "webrat:integration", "rails:webrat", "rails:webrat:integration"
      #
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

      def printing_commands # :nodoc:
        lookup!

        (subclasses - hidden_commands).flat_map(&:printing_commands)
      end

      private
        def rails_new_with_no_path?(args)
          args == ["new"]
        end

        def split_namespace(namespace)
          case namespace
          when /^(.+):(\w+)$/
            [$1, $2]
          when ""
            ["help", "help"]
          when HELP_MAPPINGS, "help"
            ["help", "help_extended"]
          when VERSION_MAPPINGS
            ["version", "version"]
          else
            [namespace, namespace]
          end
        end

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
