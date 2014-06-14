module DdlHelper
  def with_example_table(connection, table_name, definition = nil)
    connection.exec_query("CREATE TABLE #{table_name}(#{definition})")
    yield
  ensure
    connection.exec_query("DROP TABLE #{table_name}")
  end
end
