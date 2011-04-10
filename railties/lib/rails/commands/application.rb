require 'rails/version'
require 'active_support/core_ext/object/inclusion'

if ARGV.first.either?('--version', '-v')
  puts "Rails #{Rails::VERSION::STRING}"
  exit(0)
end

if ARGV.first != "new"
  ARGV[0] = "--help"
else
  ARGV.shift
end

require 'rubygems' if ARGV.include?("--dev")

require 'rails/generators'
require 'rails/generators/rails/app/app_generator'

module Rails
  module Generators
    class AppGenerator
      # We want to exit on failure to be kind to other libraries
      # This is only when accessing via CLI
      def self.exit_on_failure?
        true
      end
    end
  end
end

Rails::Generators::AppGenerator.start
