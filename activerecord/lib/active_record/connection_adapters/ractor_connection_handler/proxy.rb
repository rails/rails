# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionHandler # :nodoc:
      # The boundary between worker Ractors and the main Ractor, which owns
      # the real connection handler, pools, and physical connections.
      #
      # The worker-side stand-ins (the handler, the pool, the proxy adapters)
      # address main-side objects by value: pools by connection name, role,
      # and shard; physical connections by the token this module hands out
      # when a connection is pinned to a worker. `main_operation` runs a
      # block on the main Ractor with this module as `self`, so the block
      # resolves those addresses (`main_pool`, `fetch_connection`) without
      # naming the module.
      #
      # The worker-callable half is a set of module functions: stand-ins
      # include the module and call them unqualified (privately), while
      # `Proxy.foo` stays public for the main side and for the
      # `main_operation` blocks. The main-side half — the token registry and
      # the lookups it serves — exists only on the module.
      module Proxy # :nodoc:
        class ErrorResponse
          def initialize(error)
            @error_class = error.class
            @message = error.message.to_s
            @backtrace = error.backtrace
            @ivars = error.instance_variables.excluding(:@connection_pool).to_h do |name|
              value = error.instance_variable_get(name)
              value = value.is_a?(Proc) ?
                ActiveSupport::Ractors.shareable_proc(&value) :
                ActiveSupport::Ractors.make_shareable(value)
              [name, value]
            end
            ActiveSupport::Ractors.make_shareable(self, copy: false)
          end

          def exception(connection_pool: nil)
            error = @error_class.allocate.exception(@message)
            @ivars.each { |name, value| error.instance_variable_set(name, value) }
            error.instance_variable_set(:@connection_pool, connection_pool) if error.is_a?(AdapterError)
            error.set_backtrace(@backtrace) if @backtrace
            error
          end
        end

        module_function

        # Runs `block` on the main Ractor with this module as `self`. A
        # main-Ractor caller (self-proxy) runs it inline and errors propagate
        # as the original exception objects. For a worker caller the block
        # must capture only shareable objects; its result crosses through
        # the dispatch port (by reference when shareable, else as a native
        # copy), and a main-side error travels back as an ErrorResponse and
        # is re-raised on the calling side.
        def main_operation(connection_pool: nil, &block)
          if ActiveSupport::Ractors.main?
            begin
              return Proxy.instance_exec(&block)
            rescue AdapterError => error
              # Main-side translation attached the physical pool; point the
              # error at the pool the caller holds, as ErrorResponse does.
              error.instance_variable_set(:@connection_pool, connection_pool) if connection_pool
              raise
            end
          end

          operation = ActiveSupport::Ractors.shareable_proc(self: Proxy, &block)
          outcome = ActiveSupport::Ractors.on_main do
            Proxy.capture_transport_errors { operation.call }
          end
          raise outcome.exception(connection_pool: connection_pool) if outcome.is_a?(ErrorResponse)
          outcome
        end

        def dump_binds(binds)
          return nil if binds.nil? || binds.empty?

          dump_object(binds.map { |bind| boundary_safe_bind(bind) }, "bind parameters")
        end

        def dump_column_types(result)
          types = result.columns.map { |name| result.column_types[name] }
          return nil if types.all?(&:nil?)

          begin
            Marshal.dump(types).freeze
          rescue TypeError
            # Drop only the unmarshalable entries; `ActiveRecord::Result`
            # falls back to `Type.default_value` for nil entries.
            safe_types = types.map do |type|
              Marshal.dump(type)
              type
            rescue TypeError
              nil
            end
            Marshal.dump(safe_types).freeze
          end
        end

        def dump_object(value, description)
          Marshal.dump(value).freeze
        rescue TypeError => error
          raise ActiveRecordError, "Cannot send #{description} across the Ractor boundary: #{error.message}"
        end

        # Attribute types may close over procs (normalized attributes,
        # serialized coders); the database value is resolved locally and
        # crosses as a plain attribute with a pass-through type.
        def boundary_safe_bind(bind)
          return bind unless bind.is_a?(ActiveModel::Attribute)
          return bind if bind.value_before_type_cast.is_a?(StatementCache::Substitute)

          safe = Relation::QueryAttribute.new(bind.name, bind.value_for_database, ActiveModel::Type.default_value)
          safe.value_for_database # resolve the memo so a frozen copy never mutates
          safe
        end

        # --- Token lifecycle: give a pinned connection back ---

        def checkin_token(connection_token)
          main_operation do
            if connection = take_back_connection(connection_token)
              connection.pool.checkin(connection) if connection.in_use?
            end
            nil
          end
        end

        # Backs `AbstractAdapter#throw_away!` on the worker.
        def remove_token(connection_token)
          main_operation do
            if connection = take_back_connection(connection_token)
              connection.pool.remove(connection)
              connection.disconnect!
            end
            nil
          end
        end

        def discard_token(connection_token)
          main_operation do
            if connection = take_back_connection(connection_token)
              connection.pool.remove(connection)
              connection.discard!
            end
            nil
          end
        end

        # External lifecycle hook: releases every token-pinned connection.
        # Intended for supervisors that tear down worker Ractors, since a
        # worker that dies abruptly cannot release its own tokens.
        def checkin_all_connections
          main_operation do
            @connections_lock.synchronize do
              @connections.each_value do |connection|
                reclaim(connection)
                connection.pool.checkin(connection) if connection.in_use?
              end
              @connections.clear
            end
            nil
          end
        end

        # Whether the token still names a live, checked-out main-side
        # connection. False once anything main-side took the physical
        # connection back (e.g. ActiveRecord.disconnect_all! on the real
        # pools).
        def connection_pinned?(connection_token)
          main_operation do
            connection = @connections_lock.synchronize { @connections[connection_token] }
            !!(connection && connection.in_use?)
          end
        end

        # --- Main Ractor only: the token registry and the lookups it serves ---

        @connections = {}
        @next_token = 0
        @connections_lock = Mutex.new

        class << self
          attr_reader :connections

          # Only public because `on_main` blocks run with a nil `self`.
          def capture_transport_errors
            yield
          rescue => error
            ErrorResponse.new(error)
          end

          # The handler that owns the real pools on the main Ractor. Resolved
          # as `default_connection_handler` rather than `connection_handler`:
          # main-side dispatch threads carry no per-thread handler state, and
          # in a self-proxy run (tests on the main Ractor routed through the
          # Ractor handler) `connection_handler` would resolve back to the
          # proxying handler itself.
          def main_connection_handler
            ActiveRecord::Base.default_connection_handler
          end

          def main_pool(connection_name, role, shard)
            main_connection_handler.retrieve_connection_pool(
              connection_name,
              role: role,
              shard: shard,
              strict: true,
            )
          end

          # Pins `connection` to the worker that checked it out and returns
          # the token addressing it from then on.
          def register_connection(connection)
            # Not folded into connect! (the shared bootstrap for every
            # adapter): only this callsite knows the connection is being
            # pinned. steal! clears the flag when the lease is taken back.
            connection.proxied = true
            @connections_lock.synchronize do
              token = (@next_token += 1)
              @connections[token] = connection
              token
            end
          end

          def fetch_connection(connection_token)
            connection = @connections_lock.synchronize { @connections[connection_token] }
            unless connection
              raise ConnectionNotEstablished, "The Ractor-pinned connection for token #{connection_token.inspect} has been released"
            end
            connection
          end

          # Forked children inherit the registry, but the underlying pools and
          # connections were just discarded (PoolConfig.discard_pools!); the
          # inherited tokens are dead and must not be checked back in.
          def forget_all_connections!
            @connections_lock.synchronize { @connections.clear }
          end

          private
            def take_back_connection(connection_token)
              if connection = @connections_lock.synchronize { @connections.delete(connection_token) }
                reclaim(connection)
                connection
              end
            end

            # Token-pinned connections are leased on whichever thread ran the
            # checkout operation (usually the dispatch executor). Reassign
            # ownership to the current thread so pool checkin/removal is legal
            # from any main-Ractor thread.
            def reclaim(connection)
              connection.steal! if connection.in_use?
            end
        end
      end
    end
  end
end

ActiveSupport::ForkTracker.after_fork { ActiveRecord::ConnectionAdapters::RactorConnectionHandler::Proxy.forget_all_connections! }
