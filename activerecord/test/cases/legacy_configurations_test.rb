# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class LegacyConfigurationsTest < ActiveRecord::TestCase
    def test_can_turn_configurations_into_a_hash
      assert ActiveRecord::Base.configurations.to_h.is_a?(Hash), "expected to be a hash but was not."
      assert_equal ["arunit", "arunit2", "arunit_without_prepared_statements"].sort, ActiveRecord::Base.configurations.to_h.keys.sort
    end

    def test_each_is_deprecated
      assert_deprecated do
        ActiveRecord::Base.configurations.each do |db_config|
          assert_equal "primary", db_config.spec_name
        end
      end
    end

    def test_first_is_deprecated
      assert_deprecated do
        db_config = ActiveRecord::Base.configurations.first
        assert_equal "arunit", db_config.env_name
        assert_equal "primary", db_config.spec_name
      end
    end

    def test_fetch_is_deprecated
      assert_deprecated do
        db_config = ActiveRecord::Base.configurations.fetch("arunit").first
        assert_equal "arunit", db_config.env_name
        assert_equal "primary", db_config.spec_name
      end
    end

    def test_values_are_deprecated
      config_hashes = ActiveRecord::Base.configurations.configurations.map(&:config)
      assert_deprecated do
        assert_equal config_hashes, ActiveRecord::Base.configurations.values
      end
    end
  end
end
