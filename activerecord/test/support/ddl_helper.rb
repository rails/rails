# frozen_string_literal: true

module DdlHelper
  def with_example_table(connection, table_name, definition = nil)
    connection.execute("CREATE TABLE #{table_name}(#{definition})")
    yield
  ensure
    connection.drop_table(table_name)
  end
end
