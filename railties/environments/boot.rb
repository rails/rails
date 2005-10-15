unless defined?(RAILS_ROOT)
require 'pathname'
  root_path = Pathname.new(File.join(File.dirname(__FILE__), '..'))
  RAILS_ROOT = root_path.cleanpath.to_s + '/'
end

if File.directory?("#{RAILS_ROOT}/vendor/rails")
  require "#{RAILS_ROOT}/vendor/rails/railties/lib/initializer"
else
  require 'rubygems'
  require 'initializer'
end

Rails::Initializer.run(:set_load_path)