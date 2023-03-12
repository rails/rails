# frozen_string_literal: true

module Rails
  module Command
    class ApplicationCommand < Base # :nodoc:
      hide_command!

      self.bin = "rails"

      def help
        perform # Punt help output to the generator.
      end

      def perform(*args)
        require "rails/generators"
        require "rails/generators/rails/app/app_generator"

        Rails::Generators::AppGenerator.extend(ExitOnFailure)
        Rails::Generators::AppGenerator.start \
          Rails::Generators::ARGVScrubber.new(args).prepare!
      end

      private
        module ExitOnFailure # :nodoc:
          # Causes Thor to exit with a non-zero status on failure.
          def exit_on_failure?
            true
          end
        end
    end
  end
end
