# frozen_string_literal: true

require "rails/generators"
require "rails/generators/rails/app/app_generator"

module Rails
  module Generators
    class AppGenerator # :nodoc:
      # We want to exit on failure to be kind to other libraries
      # This is only when accessing via CLI
      def self.exit_on_failure?
        true
      end
    end
  end

  module Command
    class ApplicationCommand < Base # :nodoc:
      hide_command!

      def help
        perform # Print help output to the generator.
      end

      def perform(*args)
        Rails::Generators::AppGenerator.start \
          Rails::Generators::ARGVScrubber.new(args).prepare!
      end
    end
  end
end
