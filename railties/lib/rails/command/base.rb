# frozen_string_literal: true

require "thor"
require "erb"

require "active_support/core_ext/string/filters"
require "active_support/core_ext/string/inflections"

require "rails/command/actions"

module Rails
  module Command
    class Base < Thor
      class Error < Thor::Error # :nodoc:
      end

      include Actions

      class << self
        def exit_on_failure? # :nodoc:
          false
        end

        # Returns true when the app is a Rails engine.
        def engine?
          defined?(ENGINE_ROOT)
        end

        # Tries to get the description from a USAGE file one folder above the command
        # root.
        def desc(usage = nil, description = nil, options = {})
          if usage
            super
          else
            @desc ||= ERB.new(File.read(usage_path)).result(binding) if usage_path
          end
        end

        # Convenience method to get the namespace from the class name. It's the
        # same as Thor default except that the Command at the end of the class
        # is removed.
        def namespace(name = nil)
          if name
            super
          else
            @namespace ||= super.chomp("_command").sub(/:command:/, ":")
          end
        end

        # Convenience method to hide this command from the available ones when
        # running rails command.
        def hide_command!
          Rails::Command.hidden_commands << self
        end

        def inherited(base) #:nodoc:
          super

          if base.name && !base.name.end_with?("Base")
            Rails::Command.subclasses << base
          end
        end

        def perform(command, args, config) # :nodoc:
          if Rails::Command::HELP_MAPPINGS.include?(args.first)
            command, args = "help", []
          end

          dispatch(command, args.dup, nil, config)
        end

        def printing_commands
          namespaced_commands
        end

        def executable
          "rails #{command_name}"
        end

        # Use Rails' default banner.
        def banner(*)
          "#{executable} #{arguments.map(&:usage).join(' ')} [options]".squish
        end

        # Sets the base_name taking into account the current class namespace.
        #
        #   Rails::Command::TestCommand.base_name # => 'rails'
        def base_name
          @base_name ||= begin
            if base = name.to_s.split("::").first
              base.underscore
            end
          end
        end

        # Return command name without namespaces.
        #
        #   Rails::Command::TestCommand.command_name # => 'test'
        def command_name
          @command_name ||= begin
            if command = name.to_s.split("::").last
              command.chomp!("Command")
              command.underscore
            end
          end
        end

        # Path to lookup a USAGE description in a file.
        def usage_path
          if default_command_root
            path = File.join(default_command_root, "USAGE")
            path if File.exist?(path)
          end
        end

        # Default file root to place extra files a command might need, placed
        # one folder above the command file.
        #
        # For a Rails::Command::TestCommand placed in <tt>rails/command/test_command.rb</tt>
        # would return <tt>rails/test</tt>.
        def default_command_root
          path = File.expand_path(relative_command_path, __dir__)
          path if File.exist?(path)
        end

        private
          # Allow the command method to be called perform.
          def create_command(meth)
            if meth == "perform"
              alias_method command_name, meth
            else
              # Prevent exception about command without usage.
              # Some commands define their documentation differently.
              @usage ||= ""
              @desc  ||= ""

              super
            end
          end

          def command_root_namespace
            (namespace.split(":") - %w(rails)).join(":")
          end

          def relative_command_path
            File.join("../commands", *command_root_namespace.split(":"))
          end

          def namespaced_commands
            commands.keys.map do |key|
              if command_root_namespace.match?(/(\A|:)#{key}\z/)
                command_root_namespace
              else
                "#{command_root_namespace}:#{key}"
              end
            end
          end
      end

      def help
        if command_name = self.class.command_name
          self.class.command_help(shell, command_name)
        else
          super
        end
      end
    end
  end
end
