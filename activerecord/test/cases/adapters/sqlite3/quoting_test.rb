# frozen_string_literal: true

require "cases/helper"
require "bigdecimal"
require "securerandom"

class SQLite3QuotingTest < ActiveRecord::SQLite3TestCase
  def setup
    super
    @conn = ActiveRecord::Base.lease_connection
  end

  def test_quote_string
    assert_equal "''", @conn.quote_string("'")
  end

  def test_quote_column_name
    [@conn, @conn.class].each do |adapter|
      assert_equal '"foo"', adapter.quote_column_name("foo")
      assert_equal '"hel""lo"', adapter.quote_column_name(%{hel"lo})
    end
  end

  def test_quote_table_name
    [@conn, @conn.class].each do |adapter|
      assert_equal '"foo"', adapter.quote_table_name("foo")
      assert_equal '"foo"."bar"', adapter.quote_table_name("foo.bar")
      assert_equal '"hel""lo.wol\\d"', adapter.quote_column_name('hel"lo.wol\\d')
    end
  end

  def test_type_cast_binary_encoding_without_logger
    @conn.extend(Module.new { def logger; end })
    binary = SecureRandom.hex
    expected = binary.dup.encode!(Encoding::UTF_8)
    assert_equal expected, @conn.type_cast(binary)
  end

  def test_type_cast_true
    assert_equal 1, @conn.type_cast(true)
  end

  def test_type_cast_false
    assert_equal 0, @conn.type_cast(false)
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

  def test_quoted_time_dst_utc
    with_env_tz "America/New_York" do
      with_timezone_config default: :utc do
        t = Time.new(2000, 7, 1, 0, 0, 0, "+04:30")

        expected = t.change(year: 2000, month: 1, day: 1)
        expected = expected.getutc.to_fs(:db).sub(/\A\d\d\d\d-\d\d-\d\d /, "2000-01-01 ")

        assert_equal expected, @conn.quoted_time(t)
      end
    end
  end

  def test_quoted_time_dst_local
    with_env_tz "America/New_York" do
      with_timezone_config default: :local do
        t = Time.new(2000, 7, 1, 0, 0, 0, "+04:30")

        expected = t.change(year: 2000, month: 1, day: 1)
        expected = expected.getlocal.to_fs(:db).sub(/\A\d\d\d\d-\d\d-\d\d /, "2000-01-01 ")

        assert_equal expected, @conn.quoted_time(t)
      end
    end
  end
end
