require "cases/helper"

module ActiveRecord
  class InvertableMigrationTest < ActiveRecord::TestCase
    class SilentMigration < ActiveRecord::Migration
      def write(text = '')
        # sssshhhhh!!
      end
    end

    class InvertableMigration < SilentMigration
      def change
        create_table("horses") do |t|
          t.column :content, :text
          t.column :remind_at, :datetime
        end
      end
    end

    class NonInvertableMigration < SilentMigration
      def change
        create_table("horses") do |t|
          t.column :content, :text
          t.column :remind_at, :datetime
        end
        remove_column "horses", :content
      end
    end

    def treardown
      if ActiveRecord::Base.connection.table_exists?("horses")
        ActiveRecord::Base.connection.drop_table("horses")
      end
    end

    def test_no_reverse
      migration = NonInvertableMigration.new
      migration.migrate(:up)
      assert_raises(IrreversibleMigration) do
        migration.migrate(:down)
      end
    end

    def test_up
      migration = InvertableMigration.new
      migration.migrate(:up)
      assert migration.connection.table_exists?("horses"), "horses should exist"
    end

    def test_down
      migration = InvertableMigration.new
      migration.migrate :up
      migration.migrate :down
      assert !migration.connection.table_exists?("horses")
    end
  end
end
