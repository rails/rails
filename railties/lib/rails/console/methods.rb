# frozen_string_literal: true

Rails.deprecator.warn(<<~MSG, caller_locations(0..1))
`rails/console/methods` has been deprecated and will be removed in Rails 8.1.
Please directly use IRB's extension API to add new commands or helpers to the console.
For more details, please visit: https://github.com/ruby/irb/blob/master/EXTEND_IRB.md
MSG
