begin
  # Prefer gems to the bundled libs.
  require 'rubygems'
  gem 'thor', '>= 0.11.1'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/thor-0.11.1/lib"
end

require 'thor'
