# Prefer gems to the bundled libs.
require 'rubygems'

begin
  gem 'tmail', '~> 1.2.1'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/vendor/tmail-1.2.1"
end

begin
  gem 'text-format', '>= 0.6.3'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/vendor/text-format-0.6.3"
end
