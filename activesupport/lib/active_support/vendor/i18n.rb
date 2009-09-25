begin
  gem 'i18n', '~> 0.1.3'
rescue LoadError, NoMethodError
  $LOAD_PATH.unshift File.expand_path("#{File.dirname(__FILE__)}/i18n-0.1.3/lib")
end

require 'i18n'
