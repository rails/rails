# frozen_string_literal: true

require "cases/helper"

class Mysql2DatetimePrecisionQuotingTest < ActiveRecord::Mysql2TestCase
  setup do
    @connection = ActiveRecord::Base.connection
  end

  test "microsecond precision for MySQL" do
    assert_microsecond_precision
  end

  test "microsecond precision for MariaDB gte 5.3.0" do
    stub_version "5.5.5-10.1.8-MariaDB-log" do
      assert_microsecond_precision
    end
  end

  private
    def assert_microsecond_precision
      assert_match_quoted_microsecond_datetime(/\.123456\z/)
    end

    def assert_match_quoted_microsecond_datetime(match)
      assert_match match, @connection.quoted_date(Time.now.change(sec: 55, usec: 123456))
    end

    def stub_version(full_version_string)
      @connection.stub(:get_full_version, full_version_string) do
        @connection.schema_cache.clear!
        yield
      end
    ensure
      @connection.schema_cache.clear!
    end
end
