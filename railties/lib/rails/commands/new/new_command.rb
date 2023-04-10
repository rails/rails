# frozen_string_literal: true

module Rails
  module Command
    class NewCommand < Base # :nodoc:
      self.bin = "rails"

      no_commands do
        def help
          Rails::Command.invoke :application, [ "--help" ]
        end
      end

      def perform(*)
        say "Can't initialize a new Rails application within the directory of another, please change to a non-Rails directory first.\n"
        say "Type 'rails' for help."
        exit 1
      end
    end
  end
end
