require 'rubygems'

begin
  gem 'rack', '~> 0.4.0'
  require 'rack'
rescue Gem::LoadError
  $LOAD_PATH << "#{File.dirname(__FILE__)}/rack-0.4.0"
  require 'rack'
end
