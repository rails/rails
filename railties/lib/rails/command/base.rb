# frozen_string_literal: true

require "thor"
require "erb"

require "active_support/core_ext/class/attribute"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/string/inflections"

require "rails/command/actions"

module Rails
  module Command
    class Base < Thor
      class Error < Thor::Error # :nodoc:
      end

      include Actions

      class_attribute :bin, instance_accessor: false, default: "bin/rails"

      class << self
        def exit_on_failure? # :nodoc:
          false
        end

        # Returns true when the app is a \Rails engine.
        def engine?
          defined?(ENGINE_ROOT)
        end

        # Tries to get the description from a USAGE file one folder above the command
        # root.
        def desc(usage = nil, description = nil, options = {})
          if usage
            super
          else
            class_usage
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

        def inherited(base) # :nodoc:
          super

          if base.name && !base.name.end_with?("Base")
            Rails::Command.subclasses << base
          end
        end

        def perform(command, args, config) # :nodoc:
          if Rails::Command::HELP_MAPPINGS.include?(args.first)
            command, args = "help", [command]
            args.clear if instance_method(:help).arity.zero?
          end

          dispatch(command, args.dup, nil, config)
        end

        def printing_commands
          commands.filter_map do |name, command|
            [namespaced_name(name), command.description] unless command.hidden?
          end
        end

        def executable(command_name = self.command_name)
          "#{bin} #{namespaced_name(command_name)}"
        end

        def banner(command = nil, *)
          if command
            # Similar to Thor's banner, but show the namespace (minus the
            # "rails:" prefix), and show the command's declared bin instead of
            # the command runner.
            command.formatted_usage(self).gsub(/^#{namespace}:(\w+)/) { executable($1) }
          else
            executable
          end
        end

        # Override Thor's class-level help to also show the USAGE.
        def help(shell, *) # :nodoc:
          super
          shell.say class_usage if class_usage
        end

        # Sets the base_name taking into account the current class namespace.
        #
        #   Rails::Command::TestCommand.base_name # => 'rails'
        def base_name
          @base_name ||= if base = name.to_s.split("::").first
            base.underscore
          end
        end

        # Return command name without namespaces.
        #
        #   Rails::Command::TestCommand.command_name # => 'test'
        def command_name
          @command_name ||= if command = name.to_s.split("::").last
            command.chomp!("Command")
            command.underscore
          end
        end

        def class_usage # :nodoc:
          if usage_path
            @class_usage ||= ERB.new(File.read(usage_path), trim_mode: "-").result(binding)
          end
        end

        # Path to lookup a USAGE description in a file.
        def usage_path
          @usage_path = resolve_path("USAGE") unless defined?(@usage_path)
          @usage_path
        end

        # Default file root to place extra files a command might need, placed
        # one folder above the command file.
        #
        # For a Rails::Command::TestCommand placed in <tt>rails/command/test_command.rb</tt>
        # would return <tt>rails/test</tt>.
        def default_command_root
          @default_command_root = resolve_path(".") unless defined?(@default_command_root)
          @default_command_root
        end

        private
          # Allow the command method to be called perform.
          def create_command(meth)
            if meth == "perform"
              alias_method command_name, meth
            else
              # Prevent exception about command without usage.
              # Some commands define their documentation differently.
              @usage ||= meth
              @desc  ||= ""

              super
            end
          end

          def namespaced_name(name)
            *prefix, basename = namespace.delete_prefix("rails:").split(":")
            prefix.concat([basename, name.to_s].uniq).join(":")
          end

          def resolve_path(path)
            path = File.join("../commands", *namespace.delete_prefix("rails:").split(":"), path)
            path = File.expand_path(path, __dir__)
            path if File.exist?(path)
          end
      end

      no_commands do
        delegate :executable, to: :class
        attr_reader :current_subcommand

        def invoke_command(command, *) # :nodoc:
          @current_subcommand ||= nil
          original_subcommand, @current_subcommand = @current_subcommand, command.name
          super
        ensure
          @current_subcommand = original_subcommand
        end
      end
    end
  end
end
