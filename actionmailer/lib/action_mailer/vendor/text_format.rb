# Prefer gems to the bundled libs.
require 'rubygems'

begin
  gem 'text-format', '>= 0.6.3'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/text-format-0.6.3"
end

require 'text/format'
