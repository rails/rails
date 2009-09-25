begin
  gem 'tzinfo', '~> 0.3.13'
rescue LoadError, NoMethodError
  $LOAD_PATH.unshift File.expand_path("#{File.dirname(__FILE__)}/tzinfo-0.3.13/lib")
end

require 'tzinfo'
