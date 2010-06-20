# Prefer gems to the bundled libs.
require 'rubygems'

begin
  gem 'builder', '~> 2.1.2'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/vendor/builder-2.1.2"
end
require 'builder'

begin
  gem 'memcache-client', '>= 1.7.4'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/vendor/memcache-client-1.7.4"
end

begin
  gem 'tzinfo', '~> 0.3.12'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/vendor/tzinfo-0.3.12"
end

begin
  gem 'i18n', '>= 0.4.1'
rescue Gem::LoadError
  $:.unshift "#{File.dirname(__FILE__)}/vendor/i18n-0.4.1"
end
require 'i18n'

module I18n
  if !respond_to?(:normalize_translation_keys) && respond_to?(:normalize_keys)
    def self.normalize_translation_keys(*args)
      normalize_keys(*args)
    end
  end
end
