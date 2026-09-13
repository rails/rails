# frozen_string_literal: true

# :markup: markdown

require "active_record/connection_adapters/ractor_connection_handler/proxy"

module ActiveRecord
  module ConnectionAdapters
    # Worker-Ractor stand-in for ConnectionHandler, and the namespace of the
    # stand-ins it hands out: ProxyConnectionPool for the main-Ractor pools
    # and the AbstractProxyAdapter family for their connections. Proxy is
    # the channel all of them use to reach the main Ractor, which keeps
    # owning the real handler, pools, and physical connections.
    #
    # This class and Proxy stay loadable on a Ruby without Ractor::Port
    # (the main-side handler checks `is_a?` against it); the pool and the
    # proxy adapters load on first use, and dispatching itself needs
    # ractor-dispatch.
    class RactorConnectionHandler # :nodoc:
      autoload :ProxyConnectionPool, "active_record/connection_adapters/ractor_connection_handler/proxy_connection_pool"
      autoload :AbstractProxyAdapter, "active_record/connection_adapters/ractor_connection_handler/abstract_proxy_adapter"
      autoload :MysqlProxyAdapter, "active_record/connection_adapters/ractor_connection_handler/mysql_proxy_adapter"
      autoload :PostgreSQLProxyAdapter, "active_record/connection_adapters/ractor_connection_handler/postgresql_proxy_adapter"
      autoload :SQLite3ProxyAdapter, "active_record/connection_adapters/ractor_connection_handler/sqlite3_proxy_adapter"

      include Proxy

      def self.instance
        ActiveSupport::Ractors[:active_record_ractor_connection_handler_instance] ||= new
      end

      # Blocks handed to main_operation may only capture single-assignment
      # locals: a parameter with a computed default counts as reassignable
      # to Ractor.shareable_proc, so each is copied first.
      def connection_pool_list(role = nil)
        connection_role = role
        pool_specs = main_operation do
          specs = main_connection_handler.connection_pool_list(connection_role).map { |pool| pool.pool_config.pool_spec }
          ActiveSupport::Ractors.make_shareable(specs, copy: false)
        end
        pool_specs.map { |pool_spec| ProxyConnectionPool.for_spec(pool_spec) }
      end
      alias :connection_pools :connection_pool_list

      def connection_pool_names
        connection_pool_list.map { |pool| pool.connection_descriptor.name }.uniq
      end

      def each_connection_pool(role = nil, &block)
        return enum_for(__method__, role) unless block_given?

        connection_pool_list(role).each(&block)
      end

      def retrieve_connection(connection_name, role: ActiveRecord::Base.current_role, shard: ActiveRecord::Base.current_shard)
        retrieve_connection_pool(connection_name, role: role, shard: shard, strict: true).lease_connection
      end

      def retrieve_connection_pool(connection_name, role: ActiveRecord::Base.current_role, shard: ActiveRecord::Base.current_shard, strict: false)
        shareable_connection_name = shareable_copy(connection_name.to_s)
        connection_role = role
        connection_shard = shard
        strict_lookup = strict

        pool_spec = main_operation do
          pool = main_connection_handler.retrieve_connection_pool(
            shareable_connection_name,
            role: connection_role,
            shard: connection_shard,
            strict: strict_lookup,
          )
          pool && pool.pool_config.pool_spec
        end
        pool_spec && ProxyConnectionPool.for_spec(pool_spec)
      end

      def connected?(connection_name, role: ActiveRecord::Base.current_role, shard: ActiveRecord::Base.current_shard)
        pool = retrieve_connection_pool(connection_name, role: role, shard: shard)
        pool && pool.connected?
      end

      def active_connections?(role = nil)
        each_connection_pool(role).any?(&:active_connection?)
      end

      def clear_active_connections!(role = nil)
        each_connection_pool(role).each do |pool|
          pool.release_connection
          pool.disable_query_cache!
        end
      end

      def clear_reloadable_connections!(role = nil)
        clear_active_connections!(role)
      end

      def clear_all_connections!(role = nil)
        each_connection_pool(role).each(&:disconnect!)
      end

      def flush_idle_connections!(role = nil)
        each_connection_pool(role).each(&:flush!)
      end

      def establish_connection(config, owner_name: Base, role: Base.current_role, shard: Base.current_shard, clobber: false)
        connection_owner_name = owner_name
        db_config = shareable_copy(config)
        connection_role = role
        connection_shard = shard
        clobber_existing = clobber

        pool_spec = main_operation do
          # The boundary copy compares equal to the existing pool's config
          # (HashConfig#==), so the main handler reuses the pool exactly like
          # a direct call with an equal config.
          pool = main_connection_handler.establish_connection(
            db_config,
            owner_name: connection_owner_name,
            role: connection_role,
            shard: connection_shard,
            clobber: clobber_existing,
          )
          pool.pool_config.pool_spec
        end

        ProxyConnectionPool.for_spec(pool_spec)
      end

      def remove_connection_pool(connection_name, role: ActiveRecord::Base.current_role, shard: ActiveRecord::Base.current_shard)
        shareable_connection_name = shareable_copy(connection_name.to_s)
        connection_role = role
        connection_shard = shard

        db_config = main_operation do
          main_connection_handler.remove_connection_pool(
            shareable_connection_name, role: connection_role, shard: connection_shard
          )
        end
        shareable_copy(db_config)
      end

      def main_ractor_handler
        Proxy.main_connection_handler
      end
    end
  end
end
