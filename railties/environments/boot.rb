require 'pathname'
RAILS_ROOT = Pathname.new(File.join(File.dirname(__FILE__), '..')).cleanpath.to_s + '/' unless defined?(RAILS_ROOT)

if File.directory?("#{RAILS_ROOT}/vendor/rails")
  require "#{RAILS_ROOT}/vendor/rails/railties/lib/initializer"
else
  require 'rubygems'
  require 'initializer'
end

Rails::Initializer.run(:set_load_path)