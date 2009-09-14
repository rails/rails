# Prefer gems to the bundled libs.
require 'rubygems'

begin
  gem 'builder', '~> 2.1.2'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/vendor/builder-2.1.2/lib"
end

begin
  gem 'memcache-client', '>= 1.6.5'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/vendor/memcache-client-1.6.5/lib"
end

begin
  gem 'tzinfo', '~> 0.3.13'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/vendor/tzinfo-0.3.13/lib"
end

begin
  gem 'i18n', '~> 0.1.3'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/vendor/i18n-0.1.3/lib"
  require 'i18n'
end
