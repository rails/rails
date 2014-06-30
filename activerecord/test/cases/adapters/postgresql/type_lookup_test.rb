require 'cases/helper'

class PostgresqlTypeLookupTest < ActiveRecord::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
  end

  test "array delimiters are looked up correctly" do
    box_array = @connection.type_map.lookup(1020)
    int_array = @connection.type_map.lookup(1007)

    assert_equal ';', box_array.delimiter
    assert_equal ',', int_array.delimiter
  end
end
