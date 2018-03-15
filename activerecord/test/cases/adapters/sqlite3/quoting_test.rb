require "cases/helper"
require "bigdecimal"
require "securerandom"

class SQLite3QuotingTest < ActiveRecord::SQLite3TestCase
  def setup
    @conn = ActiveRecord::Base.connection
  end

  def test_type_cast_binary_encoding_without_logger
    @conn.extend(Module.new { def logger; end })
    binary = SecureRandom.hex
    expected = binary.dup.encode!(Encoding::UTF_8)
    assert_equal expected, @conn.type_cast(binary)
  end

  def test_type_cast_true
    assert_equal "t", @conn.type_cast(true)
  end

  def test_type_cast_false
    assert_equal "f", @conn.type_cast(false)
  end

  def test_type_cast_bigdecimal
    bd = BigDecimal "10.0"
    assert_equal bd.to_f, @conn.type_cast(bd)
  end

  def test_quoting_binary_strings
    value = "hello".encode("ascii-8bit")
    type = ActiveRecord::Type::String.new

    assert_equal "'hello'", @conn.quote(type.serialize(value))
  end

  def test_quoted_time_returns_date_qualified_time
    value = ::Time.utc(2000, 1, 1, 12, 30, 0, 999999)
    type = ActiveRecord::Type::Time.new

    assert_equal "'2000-01-01 12:30:00.999999'", @conn.quote(type.serialize(value))
  end

  def test_quoted_time_normalizes_date_qualified_time
    value = ::Time.utc(2018, 3, 11, 12, 30, 0, 999999)
    type = ActiveRecord::Type::Time.new

    assert_equal "'2000-01-01 12:30:00.999999'", @conn.quote(type.serialize(value))
  end
end
