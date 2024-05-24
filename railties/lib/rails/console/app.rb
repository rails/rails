# frozen_string_literal: true

ActiveSupport::Deprecation.new.warn(<<~MSG, caller_locations(0..1))
`rails/console/app.rb` has been deprecated and will be removed in Rails 8.0.
Please require `rails/console/methods.rb` instead.
MSG

require "rails/console/methods"
