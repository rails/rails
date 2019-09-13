# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionSpecificationTest < ActiveRecord::TestCase
      def test_dup_deep_copy_config
        spec = ConnectionSpecification.new("primary", { a: :b }, "bar")
        assert_not_equal(spec.underlying_configuration_hash.object_id, spec.dup.underlying_configuration_hash.object_id)
      end
    end
  end
end
