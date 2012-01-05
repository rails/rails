# Some code from jeremymcanally's "pending"
# https://github.com/jeremymcanally/pending/tree/master

module ActiveSupport
  module Testing
    module Pending

      unless defined?(Spec)

        @@pending_cases = []
        @@at_exit = false

        def pending(description = "", &block)
          skip(description.blank? ? nil : description)
        end
      end

    end
  end
end
