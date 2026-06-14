# frozen_string_literal: true

require "cases/helper"

class PostgreSQLVectorTest < ActiveRecord::PostgreSQLTestCase
  class VectorItem < ActiveRecord::Base
    self.table_name = "postgresql_vector_items"
  end

  def setup
    super

    @connection = ActiveRecord::Base.lease_connection

    @connection.enable_extension("vector") unless
      @connection.extension_enabled?("vector")

    @connection.execute <<~SQL
      CREATE TABLE postgresql_vector_items (
        id bigserial PRIMARY KEY,
        embedding vector(1536)
      )
    SQL
  end

  def teardown
    super

    @connection.drop_table("postgresql_vector_items", if_exists: true)
    VectorItem.reset_column_information
  end

  test "vector columns are recognized" do
    warning = capture(:stderr) do
      VectorItem.columns_hash
    end

    assert_empty warning

    column = VectorItem.columns_hash["embedding"]

    assert_equal :vector, column.type
    assert_equal "vector(1536)", column.sql_type
  end
end
