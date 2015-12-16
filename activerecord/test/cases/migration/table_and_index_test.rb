require "cases/helper"

module ActiveRecord
  class Migration
    class TableAndIndexTest < ActiveRecord::TestCase
      def test_add_schema_info_respects_prefix_and_suffix
        conn = ActiveRecord::Base.connection

        conn.drop_table(ActiveRecord::Migrator.schema_migrations_table_name, if_exists: true)
        # Use shorter prefix and suffix as in Oracle database identifier cannot be larger than 30 characters
        ActiveRecord::Base.table_name_prefix = 'p_'
        ActiveRecord::Base.table_name_suffix = '_s'
        conn.drop_table(ActiveRecord::Migrator.schema_migrations_table_name, if_exists: true)

        conn.initialize_schema_migrations_table

        assert_equal "p_unique_schema_migrations_s", conn.indexes(ActiveRecord::Migrator.schema_migrations_table_name)[0][:name]
      ensure
        ActiveRecord::Base.table_name_prefix = ""
        ActiveRecord::Base.table_name_suffix = ""
      end
    end
  end
end
