module ActiveRecord
  module ConnectionAdapters
    module Transaction # :nodoc:
      class State
        attr_reader :connection

        def initialize(connection)
          @connection = connection
        end
      end

      class Closed < State
        def begin
          Open.new(connection, self)
        end

        def closed?
          true
        end

        def open?
          false
        end

        # This is a noop when there are no open transactions
        def add_record(record)
        end
      end

      class Open < State
        attr_reader :parent, :records

        def initialize(connection, parent)
          super connection

          @parent  = parent
          @records = []

          if parent.open?
            connection.create_savepoint
          else
            connection.begin_db_transaction
          end

          connection.increment_open_transactions
        end

        def begin
          Open.new(connection, self)
        end

        def rollback
          connection.decrement_open_transactions

          if parent.open?
            connection.rollback_to_savepoint
          else
            connection.rollback_db_transaction
          end

          rollback_records
          parent
        end

        def commit
          connection.decrement_open_transactions

          begin
            if parent.open?
              connection.release_savepoint
              records.each { |r| parent.add_record(r) }
            else
              connection.commit_db_transaction
              commit_records
            end
          rescue Exception
            if parent.open?
              connection.rollback_to_savepoint
            else
              connection.rollback_db_transaction
            end

            rollback_records
            raise
          end

          parent
        end

        def add_record(record)
          records << record
        end

        def rollback_records
          records.uniq.each do |record|
            begin
              record.rolledback!(parent.closed?)
            rescue => e
              record.logger.error(e) if record.respond_to?(:logger) && record.logger
            end
          end
        end

        def commit_records
          records.uniq.each do |record|
            begin
              record.committed!
            rescue => e
              record.logger.error(e) if record.respond_to?(:logger) && record.logger
            end
          end
        end

        def closed?
          false
        end

        def open?
          true
        end
      end
    end
  end
end
