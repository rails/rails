require 'active_support'

ActiveSupport::Deprecation.warn <<-eow
Requiring rails/test_unit/railtie is deprecated and will be removed in Rails 5.1.
Please require rails/minitest/railtie instead.
eow

require 'rails/minitest/railtie'
