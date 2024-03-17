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

    setup do
      @connection = ActiveRecord::Base.lease_connection
      @connection.create_table(:cache_mes, force: true) { |t| t.timestamps }
      @connection.create_table(:cache_me_with_versions, force: true) { |t| t.timestamps }
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

    test "updated_at on class but not on instance raises an error" do
      record = CacheMeWithVersion.create
      record_from_db = CacheMeWithVersion.where(id: record.id).select(:id).first
      assert_raises(ActiveModel::MissingAttributeError, match: /'updated_at' for .*CacheMeWithVersion/) do
        record_from_db.cache_version
      end
    end
  end
end
