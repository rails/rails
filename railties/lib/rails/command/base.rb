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
        # Tries to get the description from a USAGE file one folder above the command
        # root.
        def desc(usage = nil, description = nil)
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

          if base.name && base.name !~ /Base$/
            Rails::Command.subclasses << base
          end
        end

        def perform(command, args, config) # :nodoc:
          command = nil if Thor::HELP_MAPPINGS.include?(args.first)

          dispatch(command, args.dup, nil, config)
        end

        def printing_commands
          namespace.sub(/^rails:/, "")
        end

        def executable
          "bin/rails #{command_name}"
        end

        # Use Rails' default banner.
        def banner(*)
          "#{executable} #{arguments.map(&:usage).join(' ')} [options]".squish!
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
        # For a `Rails::Command::TestCommand` placed in `rails/command/test_command.rb`
        # would return `rails/test`.
        def default_command_root
          path = File.expand_path(File.join(base_name, command_name), __dir__)
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
      end
    end
  end
end
