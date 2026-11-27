# frozen_string_literal: true

require "active_support/core_ext/object/with"

module CacheStoreDeadlineBehavior
  extend ActiveSupport::Concern

  included do
    test "#read raises if the deadline is exceeded" do
      assert_respects_deadline do
        @cache.read(SecureRandom.uuid)
      end
    end

    test "#fetch raises if the deadline is exceeded" do
      assert_respects_deadline do
        @cache.fetch(SecureRandom.uuid)
      end
    end

    test "#write raises if the deadline is exceeded" do
      assert_respects_deadline do
        @cache.write(SecureRandom.uuid, "test")
      end
    end

    test "#delete raises if the deadline is exceeded" do
      assert_respects_deadline do
        @cache.delete(SecureRandom.uuid)
      end
    end

    test "#read_multi raises if the deadline is exceeded" do
      assert_respects_deadline do
        @cache.read_multi(SecureRandom.uuid, SecureRandom.uuid)
      end
    end

    test "#write_multi raises if the deadline is exceeded" do
      assert_respects_deadline do
        @cache.write_multi({ SecureRandom.uuid => "test", SecureRandom.uuid => "test" })
      end
    end
  end

  private
    def assert_respects_deadline(&block)
      with_exceeded_deadline do
        assert_raises(ActiveSupport::Deadline::Exceeded, &block)
      end
    end

    def with_exceeded_deadline(&block)
      executor = Class.new(ActiveSupport::Executor).set_temporary_name("CacheStoreDeadlineBehavior##{name}")
      executor.default_timeout = -1
      ActiveSupport.with(executor: executor) do
        executor.wrap(&block)
      end
    end
end
