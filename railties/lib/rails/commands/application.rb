require 'rails/version'
if %w(--version -v).include? ARGV.first
  puts "Rails #{Rails::VERSION::STRING}"
  exit(0)
end

ARGV << "--help"   if ARGV.empty?
require 'rubygems' if ARGV.include?("--dev")

require 'rails/generators'
require 'rails/generators/rails/app/app_generator'

Rails::Generators::AppGenerator.start
