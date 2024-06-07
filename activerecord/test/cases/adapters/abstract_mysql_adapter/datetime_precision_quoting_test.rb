# frozen_string_literal: true

require "cases/helper"

class DatetimePrecisionQuotingTest < ActiveRecord::AbstractMysqlTestCase
  setup do
    @connection = ActiveRecord::Base.lease_connection
  end

  test "microsecond precision for MySQL gte 5.6.4" do
    stub_version "5.6.4" do
      assert_microsecond_precision
    end
  end

  test "no microsecond precision for MySQL lt 5.6.4" do
    stub_version "5.6.3" do
      assert_no_microsecond_precision
    end
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

    def assert_no_microsecond_precision
      assert_match_quoted_microsecond_datetime(/:55\z/)
    end

    def assert_match_quoted_microsecond_datetime(match)
      assert_match match, @connection.quoted_date(Time.now.change(sec: 55, usec: 123456))
    end

    def stub_version(full_version_string, &block)
      @connection.pool.pool_config.server_version = nil
      @connection.stub(:get_full_version, full_version_string, &block)
    ensure
      @connection.pool.pool_config.server_version = nil
    end
end
