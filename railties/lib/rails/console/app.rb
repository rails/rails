# frozen_string_literal: true

Rails.deprecator.warn(<<~MSG, caller_locations(0..1))
`rails/console/app` has been deprecated and will be removed in Rails 8.0.
Please require `rails/console/methods` instead.
MSG

require "rails/console/methods"
