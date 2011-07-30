require "cases/helper"

module ActiveRecord
  class InvertibleMigrationTest < ActiveRecord::TestCase
    class SilentMigration < ActiveRecord::Migration
      def write(text = '')
        # sssshhhhh!!
      end
    end

    class InvertibleMigration < SilentMigration
      def change
        create_table("horses") do |t|
          t.column :content, :text
          t.column :remind_at, :datetime
        end
      end
    end

    class NonInvertibleMigration < SilentMigration
      def change
        create_table("horses") do |t|
          t.column :content, :text
          t.column :remind_at, :datetime
        end
        remove_column "horses", :content
      end
    end

    class LegacyMigration < ActiveRecord::Migration
      def self.up
        create_table("horses") do |t|
          t.column :content, :text
          t.column :remind_at, :datetime
        end
      end

      def self.down
        drop_table("horses")
      end
    end

    def teardown
      if ActiveRecord::Base.connection.table_exists?("horses")
        ActiveRecord::Base.connection.drop_table("horses")
      end
    end

    def test_no_reverse
      migration = NonInvertibleMigration.new
      migration.migrate(:up)
      assert_raises(IrreversibleMigration) do
        migration.migrate(:down)
      end
    end

    def test_migrate_up
      migration = InvertibleMigration.new
      migration.migrate(:up)
      assert migration.connection.table_exists?("horses"), "horses should exist"
    end

    def test_migrate_down
      migration = InvertibleMigration.new
      migration.migrate :up
      migration.migrate :down
      assert !migration.connection.table_exists?("horses")
    end

    def test_legacy_up
      LegacyMigration.migrate :up
      assert ActiveRecord::Base.connection.table_exists?("horses"), "horses should exist"
    end

    def test_legacy_down
      LegacyMigration.migrate :up
      LegacyMigration.migrate :down
      assert !ActiveRecord::Base.connection.table_exists?("horses"), "horses should not exist"
    end

    def test_up
      LegacyMigration.up
      assert ActiveRecord::Base.connection.table_exists?("horses"), "horses should exist"
    end

    def test_down
      LegacyMigration.up
      LegacyMigration.down
      assert !ActiveRecord::Base.connection.table_exists?("horses"), "horses should not exist"
    end
  end
end
