# frozen_string_literal: true

require "config"

require "stringio"

require "active_record"
require "cases/test_case"
require "active_support/dependencies"
require "active_support/logger"
require "active_support/core_ext/kernel/reporting"
require "active_support/core_ext/kernel/singleton_class"

require "support/global_config"
require "support/adapter_config"
require "support/encryption_config"

ARTest::GlobalConfig.apply

class ActiveRecord::TestCase
  class SQLSubscriber
    attr_reader :logged
    attr_reader :payloads

    def initialize
      @logged = []
      @payloads = []
    end

    def start(name, id, payload)
      @payloads << payload
      @logged << [payload[:sql].squish, payload[:name], payload[:binds]]
    end

    def finish(name, id, payload); end
  end

  module InTimeZone
    private
      def in_time_zone(zone)
        old_zone  = Time.zone
        old_tz    = ActiveRecord::Base.time_zone_aware_attributes

        Time.zone = zone ? ActiveSupport::TimeZone[zone] : nil
        ActiveRecord::Base.time_zone_aware_attributes = !zone.nil?
        yield
      ensure
        Time.zone = old_zone
        ActiveRecord::Base.time_zone_aware_attributes = old_tz
      end
  end

  module WaitForAsyncTestHelper
    private
      def wait_for_async_query(connection = ActiveRecord::Base.lease_connection, timeout: 5)
        return unless connection.async_enabled?

        executor = connection.pool.async_executor
        (timeout * 100).times do
          return unless executor.scheduled_task_count > executor.completed_task_count
          sleep 0.01
        end

        raise Timeout::Error, "The async executor wasn't drained after #{timeout} seconds"
      end
  end
end
