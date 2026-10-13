# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class CacheKeyTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    class CacheMe < ActiveRecord::Base
      self.cache_versioning = false
    end

    class CacheMeWithVersion < ActiveRecord::Base
      self.cache_versioning = true
    end

    class CacheMeWithNumberVersion < ActiveRecord::Base
      self.table_name = "cache_me_with_versions"
      self.cache_versioning = true
      self.cache_timestamp_format = :number
    end

    setup do
      @connection = ActiveRecord::Base.lease_connection
      ddl_connection = main_ractor_connection(@connection)
      ddl_connection.create_table(:cache_mes, force: true) { |t| t.timestamps }
      ddl_connection.create_table(:cache_me_with_versions, force: true) { |t| t.timestamps }
    end

    teardown do
      @connection.drop_table :cache_mes, if_exists: true
      @connection.drop_table :cache_me_with_versions, if_exists: true
    end

    test "cache_key format is not too precise" do
      record = CacheMe.create
      key = record.cache_key

      assert_equal key, record.reload.cache_key
    end

    test "cache_key has no version when versioning is on" do
      record = CacheMeWithVersion.create
      assert_equal "active_record/cache_key_test/cache_me_with_versions/#{record.id}", record.cache_key
    end

    test "cache_version is only there when versioning is on" do
      assert_predicate CacheMeWithVersion.create.cache_version, :present?
      assert_not_predicate CacheMe.create.cache_version, :present?
    end

    test "cache_key_with_version always has both key and version" do
      r1 = CacheMeWithVersion.create
      assert_equal "active_record/cache_key_test/cache_me_with_versions/#{r1.id}-#{r1.updated_at.utc.to_fs(:usec)}", r1.cache_key_with_version

      r2 = CacheMe.create
      assert_equal "active_record/cache_key_test/cache_mes/#{r2.id}-#{r2.updated_at.utc.to_fs(:usec)}", r2.cache_key_with_version
    end

    test "cache_version is the same when it comes from the DB or from the user" do
      skip("Mysql2, Trilogy, and PostgreSQL don't return a string value for updated_at") if current_adapter?(:Mysql2Adapter, :TrilogyAdapter, :PostgreSQLAdapter)

      record = CacheMeWithVersion.create
      record_from_db = CacheMeWithVersion.find(record.id)
      assert_not_called(record_from_db, :updated_at) do
        record_from_db.cache_version
      end

      assert_equal record.cache_version, record_from_db.cache_version
    end

    test "cache_version does not truncate zeros when timestamp ends in zeros" do
      skip("Mysql2, Trilogy, and PostgreSQL don't return a string value for updated_at") if current_adapter?(:Mysql2Adapter, :TrilogyAdapter, :PostgreSQLAdapter)

      travel_to Time.now.beginning_of_day do
        record = CacheMeWithVersion.create
        record_from_db = CacheMeWithVersion.find(record.id)
        assert_not_called(record_from_db, :updated_at) do
          record_from_db.cache_version
        end

        assert_equal record.cache_version, record_from_db.cache_version
      end
    end

    test "cache_version calls updated_at when the value is generated at create time" do
      record = CacheMeWithVersion.create
      assert_called(record, :updated_at) do
        record.cache_version
      end
    end

    test "cache_version does NOT call updated_at when value is from the database" do
      skip("Mysql2, Trilogy, and PostgreSQL don't return a string value for updated_at") if current_adapter?(:Mysql2Adapter, :TrilogyAdapter, :PostgreSQLAdapter)

      record = CacheMeWithVersion.create
      record_from_db = CacheMeWithVersion.find(record.id)
      assert_not_called(record_from_db, :updated_at) do
        record_from_db.cache_version
      end
    end

    test "cache_version does call updated_at when it is assigned via a Time object" do
      record = CacheMeWithVersion.create
      record_from_db = CacheMeWithVersion.find(record.id)
      assert_called(record_from_db, :updated_at) do
        record_from_db.updated_at = Time.now
        record_from_db.cache_version
      end
    end

    test "cache_version does call updated_at when it is assigned via a string" do
      record = CacheMeWithVersion.create
      record_from_db = CacheMeWithVersion.find(record.id)
      assert_called(record_from_db, :updated_at) do
        record_from_db.updated_at = Time.now.to_s
        record_from_db.cache_version
      end
    end

    test "cache_version does call updated_at when it is assigned via a hash" do
      record = CacheMeWithVersion.create
      record_from_db = CacheMeWithVersion.find(record.id)
      assert_called(record_from_db, :updated_at) do
        record_from_db.updated_at = { 1 => 2016, 2 => 11, 3 => 12, 4 => 1, 5 => 2, 6 => 3, 7 => 22 }
        record_from_db.cache_version
      end
    end

    test "cache_version does not call strftime" do
      record = CacheMeWithVersion.create
      record_from_db = CacheMeWithVersion.find(record.id)

      assert_not_called_on_instance_of(Time, :strftime) do
        record.cache_version
        record_from_db.cache_version
      end
    end

    test "cache_version is updated_at in UTC, down to the microsecond" do
      record = CacheMeWithVersion.create

      [
        [Time.utc(2026, 1, 2, 3, 4, 5, 6), "20260102030405000006"],
        [Time.new(2026, 1, 2, 3, 4, 5, "+09:00"), "20260101180405000000"],
        [Time.utc(999, 12, 31, 23, 59, 59, 999_999), "09991231235959999999"],
        [Time.utc(10000, 1, 1), "100000101000000000000"],
        [Time.utc(-1, 1, 2, 3, 4, 5, 6), "-00010102030405000006"],
      ].each do |updated_at, version|
        record.updated_at = updated_at
        assert_equal version, record.cache_version
      end
    end

    test "cache_version is updated_at in UTC when attributes are time zone aware" do
      with_timezone_config aware_attributes: true, zone: "Tokyo" do
        CacheMeWithVersion.reset_column_information

        record = CacheMeWithVersion.create(updated_at: Time.utc(2026, 1, 2, 3, 4, 5, 6))
        assert_kind_of ActiveSupport::TimeWithZone, record.updated_at

        assert_equal "20260102030405000006", record.cache_version
        assert_equal "20260102030405000006", CacheMeWithVersion.find(record.id).cache_version
      ensure
        CacheMeWithVersion.reset_column_information
      end
    end

    test "cache_version follows cache_timestamp_format" do
      record = CacheMeWithNumberVersion.create
      record.updated_at = Time.utc(2026, 1, 2, 3, 4, 5, 6)

      assert_equal "20260102030405", record.cache_version
    end

    test "cache_version formats anything but a Time with to_fs" do
      timestamp = Object.new
      def timestamp.utc; self; end
      def timestamp.to_fs(format); "formatted with #{format}"; end

      record = CacheMeWithVersion.create
      record.define_singleton_method(:updated_at) { timestamp }

      assert_equal "formatted with usec", record.cache_version
    end

    test "cache_version does not call the format method of the record" do
      record = CacheMeWithVersion.create
      record.define_singleton_method(:format) { "pdf" }

      assert_equal record.updated_at.utc.to_fs(:usec), record.cache_version
    end

    test "updated_at on class but not on instance raises an error" do
      record = CacheMeWithVersion.create
      record_from_db = CacheMeWithVersion.where(id: record.id).select(:id).first
      assert_raises(ActiveModel::MissingAttributeError, match: /'updated_at' for .*CacheMeWithVersion/) do
        record_from_db.cache_version
      end
    end
  end
end
