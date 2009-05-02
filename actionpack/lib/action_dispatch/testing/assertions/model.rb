module ActionDispatch
  module Assertions
    module ModelAssertions
      # Ensures that the passed record is valid by Active Record standards and
      # returns any error messages if it is not.
      #
      # ==== Examples
      #
      #   # assert that a newly created record is valid
      #   model = Model.new
      #   assert_valid(model)
      #
      def assert_valid(record)
        ::ActiveSupport::Deprecation.warn("assert_valid is deprecated. Use assert record.valid? instead", caller)
        assert record.valid?, record.errors.full_messages.join("\n")
      end
    end
  end
end
