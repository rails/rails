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

  test "array types correctly respect registration of subtypes" do
    int_array = @connection.type_map.lookup(1007, -1, "integer[]")
    bigint_array = @connection.type_map.lookup(1016, -1, "bigint[]")
    big_array = [123456789123456789]

    assert_raises(RangeError) { int_array.type_cast_from_user(big_array) }
    assert_equal big_array, bigint_array.type_cast_from_user(big_array)
  end

  test "range types correctly respect registration of subtypes" do
    int_range = @connection.type_map.lookup(3904, -1, "int4range")
    bigint_range = @connection.type_map.lookup(3926, -1, "int8range")
    big_range = 0..123456789123456789

    assert_raises(RangeError) { int_range.type_cast_for_database(big_range) }
    assert_equal "[0,123456789123456789]", bigint_range.type_cast_for_database(big_range)
  end
end
