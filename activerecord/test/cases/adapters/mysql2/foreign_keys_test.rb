# frozen_string_literal: true

require "cases/helper"

if ActiveRecord::Base.connection.supports_foreign_keys?
  class Mysql2ForeignKeysTest < ActiveRecord::Mysql2TestCase
    setup do
      @connection = ActiveRecord::Base.connection
      @connection.create_table(:table001_tests, force: true)
    end

    teardown do
      @connection.drop_table :table001_tests, if_exists: true
    end

    class CreateTable002TestMigration < ActiveRecord::Migration::Current
      def up
        create_table :table002_tests do |t|
          t.references :table001_test, foreign_key: true, index: true
          t.references :table003_test, foreign_key: true, index: true
        end
      end

      def down
        drop_table :table002_test, if_exists: true
      end
    end

    def test_foreign_key_references_inexistant_table
      migration = CreateTable002TestMigration.new
      begin
        silence_stream($stdout) { migration.migrate(:up) }
      rescue ActiveRecord::StatementInvalid => e
        assert_match "table003_tests", e.message
        assert_no_match "table001_test_id", e.message
      end
    ensure
      silence_stream($stdout) { migration.migrate(:down) }
    end
  end
end
