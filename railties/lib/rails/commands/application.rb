require 'rails/version'

if ['--version', '-v'].include?(ARGV.first)
  puts "Rails #{Rails::VERSION::STRING}"
  exit(0)
end

if ARGV.first != "new"
  ARGV[0] = "--help"
else
  ARGV.shift
  unless ARGV.delete("--no-rc")
    customrc = ARGV.index('--rc')
    railsrc = customrc ? ARGV.slice!(customrc, 2).last : File.join(File.expand_path("~"), '.railsrc')
    if File.exist?(railsrc)
      extra_args_string = File.read(railsrc)
      extra_args = extra_args_string.split(/\n+/).map {|l| l.split}.flatten
      puts "Using #{extra_args.join(" ")} from #{railsrc}"
      ARGV.insert(1, *extra_args)
    end
  end
end

require 'rails/generators'
require 'rails/generators/rails/app/app_generator'

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

Rails::Generators::AppGenerator.start
