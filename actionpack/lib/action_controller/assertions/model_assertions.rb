module ActionController
  module Assertions
    module ModelAssertions
      # ensures that the passed record is valid by active record standards. returns the error messages if not
      def assert_valid(record)
        clean_backtrace do
          assert record.valid?, record.errors.full_messages.join("\n")
        end
      end
    end
  end
end