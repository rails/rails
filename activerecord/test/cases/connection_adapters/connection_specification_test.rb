# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionSpecificationTest < ActiveRecord::TestCase
      def test_dup_deep_copy_config
        db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new("development", "primary", { a: :b })
        spec = ConnectionSpecification.new("primary", db_config, "bar")
        assert_not_equal(spec.underlying_configuration_hash.object_id, spec.dup.underlying_configuration_hash.object_id)
      end
    end
  end
end
