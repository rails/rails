#!/usr/bin/env ruby
require 'fileutils'
include FileUtils

# path to your application root.
APP_ROOT = File.expand_path('..', __dir__)

def system!(*args)
  system(*args) || abort("\n== Command #{args} failed ==")
end

chdir APP_ROOT do
  # This script is a way to update your development environment automatically.
  # Add necessary update steps to this file.

  puts '== Installing dependencies =='
  system! 'gem install bundler --conservative'
  system('bundle check') || system!('bundle install')

  # Install JavaScript dependencies if using Yarn
  # system('bin/yarn')

  puts "\n== Updating database =="
  system! 'bin/rails db:migrate'

  puts "\n== Removing old logs and tempfiles =="
  system! 'bin/rails log:clear tmp:clear'

  puts "\n== Restarting application server =="
  system! 'bin/rails restart'
end
