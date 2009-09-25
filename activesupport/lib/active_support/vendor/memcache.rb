begin
  gem 'memcache-client', '~> 1.7.5'
rescue LoadError, NoMethodError
  $LOAD_PATH.unshift File.expand_path("#{File.dirname(__FILE__)}/memcache-client-1.7.5/lib")
end

require 'memcache'
