# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionHandler # :nodoc:
      INSTANCE = new.freeze
      def self.instance = INSTANCE

      def connection_pool_list(role = nil)
        RactorConnectionProxy.main_pool_specs(role).map { |pool_spec| RactorConnectionPool.new(pool_spec) }
      end
      alias :connection_pools :connection_pool_list

      def each_connection_pool(role = nil, &block)
        return enum_for(__method__, role) unless block_given?

        connection_pool_list(role).each(&block)
      end

      def retrieve_connection(connection_name, role: ActiveRecord::Base.current_role, shard: ActiveRecord::Base.current_shard)
        retrieve_connection_pool(connection_name, role: role, shard: shard, strict: true).lease_connection
      end

      def retrieve_connection_pool(connection_name, role: ActiveRecord::Base.current_role, shard: ActiveRecord::Base.current_shard, strict: false)
        pool_spec = RactorConnectionProxy.main_pool_spec(connection_name.to_s, role, shard, strict)
        pool_spec && RactorConnectionPool.new(pool_spec)
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
        owner_name = owner_name.name if owner_name.respond_to?(:name)
        owner_name = owner_name.to_s
        db_config = config

        pool_spec = ActiveSupport::Ractors.on_main(self) do
          pool = ActiveRecord::Base.connection_handler.establish_connection(
            db_config,
            owner_name: owner_name,
            role: role,
            shard: shard,
            clobber: clobber,
          )
          RactorConnectionPool.spec_for(pool)
        end

        RactorConnectionPool.new(pool_spec)
      end
    end
  end
end
