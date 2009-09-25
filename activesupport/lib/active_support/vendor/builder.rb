begin
  gem 'builder', '~> 2.1.2'
rescue LoadError, NoMethodError
  $LOAD_PATH.unshift File.expand_path("#{File.dirname(__FILE__)}/builder-2.1.2/lib")
end

require 'builder'
