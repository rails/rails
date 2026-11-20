# frozen_string_literal: true

require "cases/helper"

class PostgresqlTemporaryTablesTest < ActiveRecord::PostgreSQLTestCase
  class TempModel < ActiveRecord::Base
    def self.with_temp_table(as:)
      transaction do
        connection.create_table(table_name, temporary: true, force: true, as: as)
        yield
      end
    end
  end

  def test_upsert_all
    TempModel.with_temp_table(as: "select 1 as id, 'foo' as some_column") do
      TempModel.connection.add_index(TempModel.table_name, :id, unique: true)

      assert_equal TempModel.new(id: 1, some_column: "foo"), TempModel.sole

      TempModel.upsert_all([{ id: 1, some_column: "bar" }], unique_by: :id)

      assert_equal TempModel.new(id: 1, some_column: "bar2"), TempModel.sole
    end
  end
end
