require 'cases/helper'

module ActiveRecord
  class MigrationTest < ActiveRecord::TestCase
    def setup
      super
    end

    def test_error_raised_if_unknown_version_number
      assert_raises RuntimeError do
        ActiveRecord::Migration.version("6.0")
      end

      error = assert_raises RuntimeError do
        ActiveRecord::Migration.version("6.0")
      end

      assert_equal error.message, "Unkown version number: 6.0, only the following version numbers are accepted: 3.2, 4.2, 5.0"
    end

    def test_current_version_is_current_rails_version
      assert_equal ActiveRecord::Migration.current_version, ActiveRecord::VERSION::STRING.to_f
    end
  end
end
