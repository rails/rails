begin
  # Prefer gems to the bundled libs.
  require 'rubygems'
  gem 'thor', '>= 0.11.0'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/thor-0.11.0/lib"
end

require 'thor'
