# Prefer gems to the bundled libs.
require 'rubygems'

begin
  gem 'builder', '~> 2.1.2'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/vendor/builder-2.1.2"
end

begin
  gem 'xml-simple', '~> 1.0.11'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/vendor/xml-simple-1.0.11"
end

begin
  gem 'memcache-client', '~> 1.5.1'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/vendor/memcache-client-1.5.1"
end

begin
  gem 'tzinfo', '~> 0.3.12'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/vendor/tzinfo-0.3.12"
end

# TODO I18n gem has not been released yet
# begin
#   gem 'i18n', '~> 0.0.1'
# rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/vendor/i18n-0.0.1"
  require 'i18n'
# end