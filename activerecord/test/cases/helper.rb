# frozen_string_literal: true

require "config"

require "stringio"

require "active_record"
require "cases/test_case"
require "active_support/dependencies"
require "active_support/logger"
require "active_support/core_ext/kernel/reporting"
require "active_support/core_ext/kernel/singleton_class"

if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables = true
end

# TODO: Move all these random hacks into the ARTest namespace and into the support/ dir

Thread.abort_on_exception = true

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveRecord.deprecator.debug = true

# ActiveRecord::Base.connection is only soft deprecated but we ban it from the test suite
# to ensure it's not used internally.
ActiveRecord.permanent_connection_checkout = :disallowed

ActiveRecord::Delegation::DelegateCache.delegate_base_methods = false

# Ensure this alias isn't being used by Active Record itself.
ActiveRecord::Relation.remove_method(:klass)

# Disable available locale checks to avoid warnings running the test suite.
I18n.enforce_available_locales = false

# Quote "type" if it's a reserved word for the current connection.
QUOTED_TYPE = ActiveRecord::Base.lease_connection.quote_column_name("type")

ActiveRecord::Base.automatically_invert_plural_associations = true

ActiveRecord.raise_on_assign_to_attr_readonly = true
ActiveRecord.belongs_to_required_validates_foreign_key = false

ActiveRecord::ConnectionAdapters.register("abstract", "ActiveRecord::ConnectionAdapters::AbstractAdapter", "active_record/connection_adapters/abstract_adapter")
ActiveRecord::ConnectionAdapters.register("fake", "FakeActiveRecordAdapter", File.expand_path("../support/fake_adapter.rb", __dir__))

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

# Encryption

ActiveRecord::Encryption.configure \
  primary_key: "test master key",
  deterministic_key: "test deterministic key",
  key_derivation_salt: "testing key derivation salt"

# Simulate https://github.com/rails/rails/blob/735cba5bed7a54c7397dfeec1bed16033ae286f8/activerecord/lib/active_record/railtie.rb#L392
ActiveRecord::Encryption.config.extend_queries = true
ActiveRecord::Encryption::ExtendedDeterministicQueries.install_support
ActiveRecord::Encryption::ExtendedDeterministicUniquenessValidator.install_support
