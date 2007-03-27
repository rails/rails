module ActionController
  module Assertions
    module ModelAssertions
      # Ensures that the passed record is valid by ActiveRecord standards and returns any error messages if it is not.
      def assert_valid(record)
        clean_backtrace do
          assert record.valid?, record.errors.full_messages.join("\n")
        end
      end
    end
  end
end