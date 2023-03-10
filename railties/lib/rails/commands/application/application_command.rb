# frozen_string_literal: true

module Rails
  module Generators
    module ExitOnFailure # :nodoc:
      # We want to exit on failure to be kind to other libraries
      # This is only when accessing via CLI
      def exit_on_failure?
        true
      end
    end
  end

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
        Rails::Generators::AppGenerator.extend(Rails::Generators::ExitOnFailure)
        Rails::Generators::AppGenerator.start \
          Rails::Generators::ARGVScrubber.new(args).prepare!
      end
    end
  end
end
