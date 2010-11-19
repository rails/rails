require "cases/helper"

module ActiveRecord
  class InvertableMigrationTest < ActiveRecord::TestCase
    class InvertableMigration < ActiveRecord::Migration
      def change
        create_table("horses") do |t|
          t.column :content, :text
          t.column :remind_at, :datetime
        end
      end

      def write(text = '')
        # sssshhhhh!!
      end
    end

    def treardown
      if ActiveRecord::Base.connection.table_exists?("horses")
        ActiveRecord::Base.connection.drop_table("horses")
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
