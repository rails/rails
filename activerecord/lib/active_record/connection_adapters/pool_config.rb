# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class PoolConfig # :nodoc:
      include MonitorMixin

      attr_reader :db_config, :role, :shard
      attr_writer :schema_reflection, :server_version
      attr_accessor :connection_class

      def schema_reflection
        @schema_reflection ||= SchemaReflection.new(db_config.lazy_schema_cache_path)
      end

      INSTANCES = ObjectSpace::WeakMap.new
      private_constant :INSTANCES

      class << self
        def discard_pools!
          INSTANCES.each_key(&:discard_pool!)
        end

        def disconnect_all!
          INSTANCES.each_key { |c| c.disconnect!(automatic_reconnect: true) }
        end
      end

      def initialize(connection_class, db_config, role, shard)
        super()
        @server_version = nil
        @connection_class = connection_class
        @db_config = db_config
        @role = role
        @shard = shard
        @pool = nil
        INSTANCES[self] = self
      end

      def server_version(connection)
        @server_version || synchronize { @server_version ||= connection.get_database_version }
      end

      def connection_name
        if connection_class.primary_class?
          "ActiveRecord::Base"
        else
          connection_class.name
        end
      end

      def disconnect!(automatic_reconnect: false)
        return unless @pool

        synchronize do
          return unless @pool

          @pool.automatic_reconnect = automatic_reconnect
          @pool.disconnect!
        end

        nil
      end

      def pool
        @pool || synchronize { @pool ||= ConnectionAdapters::ConnectionPool.new(self) }
      end

      def discard_pool!
        return unless @pool

        synchronize do
          return unless @pool

          @pool.discard!
          @pool = nil
        end
      end
    end
  end
end

ActiveSupport::ForkTracker.after_fork { ActiveRecord::ConnectionAdapters::PoolConfig.discard_pools! }
