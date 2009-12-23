require "isolation/abstract_unit"

module PluginsTest
  class FrameworkExtensionTest < Test::Unit::TestCase
    def setup
      build_app
      boot_rails
    end

    test "active_record extensions are applied to ActiveRecord" do
      add_to_config "config.active_record.table_name_prefix = 'tbl_'"

      require "#{app_path}/config/environment"

      assert_equal 'tbl_', ActiveRecord::Base.table_name_prefix
    end
  end
end