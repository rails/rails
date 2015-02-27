module ActiveRecord
  module ConnectionAdapters
    class TransactionState
      attr_reader :parent

      VALID_STATES = Set.new([:committed, :rolledback, nil])

      def initialize(state = nil)
        @state = state
        @parent = nil
      end

      def finalized?
        @state
      end

      def committed?
        @state == :committed
      end

      def rolledback?
        @state == :rolledback
      end

      def completed?
        committed? || rolledback?
      end

      def set_state(state)
        if !VALID_STATES.include?(state)
          raise ArgumentError, "Invalid transaction state: #{state}"
        end
        @state = state
      end
    end

    class NullTransaction #:nodoc:
      def initialize; end
      def closed?; true; end
      def open?; false; end
      def joinable?; false; end
      def add_record(record); end
    end

    class Transaction #:nodoc:

      attr_reader :connection, :state, :records, :savepoint_name
      attr_writer :joinable

      def initialize(connection, options)
        @connection = connection
        @state = TransactionState.new
        @records = []
        @joinable = options.fetch(:joinable, true)
      end

      def add_record(record)
        records << record
      end

      def rollback
        @state.set_state(:rolledback)
      end

      def rollback_records
        ite = records.uniq
        while record = ite.shift
          begin
            record.rolledback! full_rollback?
          rescue => e
            raise if ActiveRecord::Base.raise_in_transactional_callbacks
            record.logger.error(e) if record.respond_to?(:logger) && record.logger
          end
        end
      ensure
        ite.each do |i|
          i.rolledback!(full_rollback?, false)
        end
      end

      def commit
        @state.set_state(:committed)
      end

      def commit_records
        ite = records.uniq
        while record = ite.shift
          begin
            record.committed!
          rescue => e
            raise if ActiveRecord::Base.raise_in_transactional_callbacks
            record.logger.error(e) if record.respond_to?(:logger) && record.logger
          end
        end
      ensure
        ite.each do |i|
          i.committed!(false)
        end
      end

      def full_rollback?; true; end
      def joinable?; @joinable; end
      def closed?; false; end
      def open?; !closed?; end
    end

    class SavepointTransaction < Transaction

      def initialize(connection, savepoint_name, options)
        super(connection, options)
        if options[:isolation]
          raise ActiveRecord::TransactionIsolationError, "cannot set transaction isolation in a nested transaction"
        end
        connection.create_savepoint(@savepoint_name = savepoint_name)
      end

      def rollback
        connection.rollback_to_savepoint(savepoint_name)
        super
        rollback_records
      end

      def commit
        connection.release_savepoint(savepoint_name)
        super
        parent = connection.transaction_manager.current_transaction
        records.each { |r| parent.add_record(r) }
      end

      def full_rollback?; false; end
    end

    class RealTransaction < Transaction

      def initialize(connection, options)
        super
        if options[:isolation]
          connection.begin_isolated_db_transaction(options[:isolation])
        else
          connection.begin_db_transaction
        end
      end

      def rollback
        connection.rollback_db_transaction
        super
        rollback_records
      end

      def commit
        connection.commit_db_transaction
        super
        commit_records
      end
    end

    class TransactionManager #:nodoc:
      def initialize(connection)
        @stack = []
        @connection = connection
      end

      def begin_transaction(options = {})
        transaction =
          if @stack.empty?
            RealTransaction.new(@connection, options)
          else
            SavepointTransaction.new(@connection, "active_record_#{@stack.size}", options)
          end
        @stack.push(transaction)
        transaction
      end

      def commit_transaction
        @stack.pop.commit
      end

      def rollback_transaction
        @stack.pop.rollback
      end

      def within_new_transaction(options = {})
        transaction = begin_transaction options
        yield
      rescue Exception => error
        rollback_transaction if transaction
        raise
      ensure
        unless error
          if Thread.current.status == 'aborting'
            rollback_transaction if transaction
          else
            begin
              commit_transaction
            rescue Exception
              transaction.rollback unless transaction.state.completed?
              raise
            end
          end
        end
      end

      def open_transactions
        @stack.size
      end

      def current_transaction
        @stack.last || NULL_TRANSACTION
      end

      private
        NULL_TRANSACTION = NullTransaction.new
    end
  end
end
