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
      @connection = ActiveRecord::Base.connection
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
      assert_equal "active_record/cache_key_test/cache_me_with_versions/#{r1.id}-#{r1.updated_at.to_s(:usec)}", r1.cache_key_with_version

      r2 = CacheMe.create
      assert_equal "active_record/cache_key_test/cache_mes/#{r2.id}-#{r2.updated_at.to_s(:usec)}", r2.cache_key_with_version
    end
  end
end
