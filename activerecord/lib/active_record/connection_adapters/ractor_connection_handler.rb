# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionHandler # :nodoc:
      def self.instance
        ActiveSupport::Ractors[:active_record_ractor_connection_handler_instance] ||= new
      end

      def connection_pool_list(role = nil)
        RactorConnectionProxy.main_pool_specs(role).map { |pool_spec| RactorConnectionPool.for_spec(pool_spec) }
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
        pool_spec = RactorConnectionProxy.main_pool_spec(connection_name.to_s, role, shard, strict)
        pool_spec && RactorConnectionPool.for_spec(pool_spec)
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
        db_config = RactorConnectionProxy.shareable_copy(config)
        connection_role = role
        connection_shard = shard
        clobber_existing = clobber

        pool_spec = ActiveSupport::Ractors.on_main do
          pool = ActiveRecord::Base.default_connection_handler.establish_connection(
            RactorConnectionHandler.identity_db_config(db_config),
            owner_name: connection_owner_name,
            role: connection_role,
            shard: connection_shard,
            clobber: clobber_existing,
          )
          RactorConnectionPool.spec_for(pool)
        end

        RactorConnectionPool.for_spec(pool_spec)
      end

      # The main handler decides pool reuse by config identity, which a
      # boundary copy always fails. Resolves a copy back to its identity
      # anchor — origin pool config or value-equal registry entry; ad-hoc
      # configs match neither and rebuild the pool, like a direct call.
      def self.identity_db_config(db_config)
        return db_config unless db_config.is_a?(DatabaseConfigurations::HashConfig)

        if origin = RactorConnectionPool.origin_db_config(db_config)
          return origin
        end

        registered = ActiveRecord::Base.configurations.configs_for(
          env_name: db_config.env_name, name: db_config.name, include_hidden: true
        )
        if registered && registered.class == db_config.class &&
            registered.configuration_hash == db_config.configuration_hash
          registered
        else
          db_config.dup
        end
      end

      def remove_connection_pool(connection_name, role: ActiveRecord::Base.current_role, shard: ActiveRecord::Base.current_shard)
        shareable_connection_name = RactorConnectionProxy.shareable_copy(connection_name.to_s)
        connection_role = role
        connection_shard = shard

        db_config = ActiveSupport::Ractors.on_main do
          ActiveRecord::Base.default_connection_handler.remove_connection_pool(
            shareable_connection_name, role: connection_role, shard: connection_shard
          )
        end
        RactorConnectionProxy.shareable_copy(db_config)
      end

      def main_ractor_handler
        ActiveRecord::Base.default_connection_handler
      end
    end
  end
end
