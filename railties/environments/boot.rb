RAILS_ROOT = File.join(File.dirname(__FILE__), '..')

unless File.directory?("#{RAILS_ROOT}/vendor/rails")
  require 'rubygems'
  require 'initializer'
else
  require "#{RAILS_ROOT}/vendor/rails/railties/lib/initializer"
end