# frozen_string_literal: true

# :markup: markdown

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionHandler # :nodoc:
      # The boundary between worker Ractors and the main Ractor, which owns
      # the real connection handler, pools, and connections.
      module Proxy # :nodoc:
        # The main-side exception behind an error raised on the calling side
        class RemoteError < ActiveRecordError
          attr_reader :error_class

          def initialize(error_class = nil, message = nil)
            @error_class = error_class
            super(message)
          end
        end

        # Shareable stand-in for a main-side exception
        class ErrorResponse
          def initialize(error)
            @error_class = error.class
            @message = error.message.to_s
            @backtrace = error.backtrace
            @cause = ErrorResponse.new(error.cause) if error.cause
            @ivars = capture_ivars(error) if reconstructible?(error)
            ActiveSupport::Ractors.make_shareable(self, copy: false)
          end

          def exception(connection_pool: nil)
            remote = remote_error
            error =
              if @ivars
                rebuilt = @error_class.allocate.exception(@message)
                @ivars.each { |name, value| rebuilt.instance_variable_set(name, value) }
                rebuilt.instance_variable_set(:@connection_pool, connection_pool) if rebuilt.is_a?(AdapterError)
                attach_cause(rebuilt, remote)
              else
                remote
              end
            error.set_backtrace(@backtrace + caller) if @backtrace
            error
          end

          def remote_error
            error = RemoteError.new(@error_class, @message)
            error.set_backtrace(@backtrace) if @backtrace
            @cause ? attach_cause(error, @cause.remote_error) : error
          end

          private
            # Only errors whose state is plain data can be rebuilt, or if it is an Active Record error.
            def reconstructible?(error)
              return true if error.is_a?(ActiveRecordError)

              error.instance_variables.empty? && !error.is_a?(SystemCallError)
            end

            def capture_ivars(error)
              error.instance_variables.each_with_object({}) do |name, ivars|
                next if name == :@connection_pool

                value = error.instance_variable_get(name)
                ivars[name] = value.is_a?(Proc) ?
                  ActiveSupport::Ractors.shareable_proc(&value) :
                  ActiveSupport::Ractors.make_shareable(value)
              end
            end

            # `raise` is the only way to set a cause.
            def attach_cause(error, cause)
              raise error, cause: cause
            rescue error.class
              error
            end
        end

        module_function

        # Proxy work to the main ractor. A worker's block may only capture shareable objects.
        def main_operation(connection_pool: nil, &block)
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
            # Result falls back to Type.default_value for nil entries.
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

        # Attribute types may close over procs, so the database value is resolved locally
        def boundary_safe_bind(bind)
          return bind unless bind.is_a?(ActiveModel::Attribute)
          return bind if bind.value_before_type_cast.is_a?(StatementCache::Substitute)

          safe = Relation::QueryAttribute.new(bind.name, bind.value_for_database, ActiveModel::Type.default_value)
          safe.value_for_database # resolve the memo so a frozen copy never mutates
          safe
        end

        def checkin_token(connection_token)
          main_operation do
            if connection = take_back_connection(connection_token)
              connection.pool.checkin(connection) if connection.in_use?
            end
            nil
          end
        end

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

        # For supervisors tearing down worker Ractors, which cannot release their own tokens when they die.
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

        def connection_pinned?(connection_token)
          main_operation do
            connection = @connections_lock.synchronize { @connections[connection_token] }
            !!(connection && connection.in_use?)
          end
        end

        @connections = {}
        @next_token = 0
        @connections_lock = Mutex.new

        class << self
          attr_reader :connections

          def capture_transport_errors
            yield
          rescue => error
            ErrorResponse.new(error)
          end

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

          def register_connection(connection)
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

          # After a fork, the inherited tokens name discarded connections and must not be checked back in.
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

            # Token-pinned connections are leased on the dispatch thread
            def reclaim(connection)
              connection.steal! if connection.in_use?
            end
        end
      end
    end
  end
end

ActiveSupport::ForkTracker.after_fork { ActiveRecord::ConnectionAdapters::RactorConnectionHandler::Proxy.forget_all_connections! }
