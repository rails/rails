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
end

args = Rails::Generators::ARGVScrubber.new(ARGV).prepare!
Rails::Generators::AppGenerator.start args
