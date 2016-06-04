require "cases/helper"
require 'bigdecimal'
require 'yaml'
require 'securerandom'

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

  def test_type_cast_symbol
    assert_equal 'foo', @conn.type_cast(:foo)
  end

  def test_type_cast_date
    date = Date.today
    expected = @conn.quoted_date(date)
    assert_equal expected, @conn.type_cast(date)
  end

  def test_type_cast_time
    time = Time.now
    expected = @conn.quoted_date(time)
    assert_equal expected, @conn.type_cast(time)
  end

  def test_type_cast_numeric
    assert_equal 10, @conn.type_cast(10)
    assert_equal 2.2, @conn.type_cast(2.2)
  end

  def test_type_cast_nil
    assert_equal nil, @conn.type_cast(nil)
  end

  def test_type_cast_true
    assert_equal 't', @conn.type_cast(true)
  end

  def test_type_cast_false
    assert_equal 'f', @conn.type_cast(false)
  end

  def test_type_cast_bigdecimal
    bd = BigDecimal.new '10.0'
    assert_equal bd.to_f, @conn.type_cast(bd)
  end

  def test_type_cast_unknown_should_raise_error
    obj = Class.new.new
    assert_raise(TypeError) { @conn.type_cast(obj) }
  end

  def test_type_cast_object_which_responds_to_quoted_id
    quoted_id_obj = Class.new {
      def quoted_id
        "'zomg'"
      end

      def id
        10
      end
    }.new
    assert_equal 10, @conn.type_cast(quoted_id_obj)

    quoted_id_obj = Class.new {
      def quoted_id
        "'zomg'"
      end
    }.new
    assert_raise(TypeError) { @conn.type_cast(quoted_id_obj) }
  end

  def test_quoting_binary_strings
    value = "hello".encode('ascii-8bit')
    type = ActiveRecord::Type::String.new

    assert_equal "'hello'", @conn.quote(type.serialize(value))
  end

  def test_quoted_time_returns_date_qualified_time
    value = ::Time.utc(2000, 1, 1, 12, 30, 0, 999999)
    type = ActiveRecord::Type::Time.new

    assert_equal "'2000-01-01 12:30:00.999999'", @conn.quote(type.serialize(value))
  end
end
