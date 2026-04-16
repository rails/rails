# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module DatabaseStatements
      def initialize
        super
        reset_transaction
      end

      # Converts an arel AST to SQL
      def to_sql(arel_or_sql_string, binds = [])
        sql, _ = to_sql_and_binds(arel_or_sql_string, binds)
        sql
      end

      def to_sql_and_binds(arel_or_sql_string, binds = [], preparable = nil, allow_retry = false) # :nodoc:
        # Arel::TreeManager -> Arel::Node
        if arel_or_sql_string.respond_to?(:ast)
          arel_or_sql_string = arel_or_sql_string.ast
        end

        if Arel.arel_node?(arel_or_sql_string) && !(String === arel_or_sql_string)
          unless binds.empty?
            raise "Passing bind parameters with an arel AST is forbidden. " \
              "The values must be stored on the AST directly"
          end

          collector = collector()
          collector.retryable = true

          if prepared_statements
            collector.preparable = true
            sql, binds = visitor.compile(arel_or_sql_string, collector)

            if binds.length > bind_params_length
              unprepared_statement do
                return to_sql_and_binds(arel_or_sql_string)
              end
            end
            preparable = collector.preparable
          else
            sql = visitor.compile(arel_or_sql_string, collector)
          end
          allow_retry = collector.retryable
          [sql.freeze, binds, preparable, allow_retry]
        else
          arel_or_sql_string = arel_or_sql_string.dup.freeze unless arel_or_sql_string.frozen?
          [arel_or_sql_string, binds, preparable, allow_retry]
        end
      end

      # This is used in the StatementCache object. It returns an object that
      # can be used to query the database repeatedly.
      def cacheable_query(klass, arel) # :nodoc:
        if prepared_statements
          collector = collector()
          collector.retryable = true
          sql, binds = visitor.compile(arel.ast, collector)
          query = klass.query(sql, retryable: collector.retryable)
        else
          collector = klass.partial_query_collector
          collector.retryable = true
          parts, binds = visitor.compile(arel.ast, collector)
          query = klass.partial_query(parts, retryable: collector.retryable)
        end
        [query, binds]
      end

      # Returns an ActiveRecord::Result instance.
      def select_all(arel, name = nil, binds = [], preparable: nil, async: false, allow_retry: false)
        arel = arel_from_relation(arel)
        intent = QueryIntent.new(
          adapter: self,
          arel: arel,
          name: name,
          binds: binds,
          prepare: preparable,
          allow_async: async,
          allow_retry: allow_retry
        )

        intent.execute!

        if async
          intent.future_result
        else
          intent.cast_result
        end
      end

      # Returns a record hash with the column names as keys and column values
      # as values.
      def select_one(arel, name = nil, binds = [], async: false)
        select_all(arel, name, binds, async: async).then(&:first)
      end

      # Returns a single value from a record
      def select_value(arel, name = nil, binds = [], async: false)
        select_rows(arel, name, binds, async: async).then { |rows| single_value_from_rows(rows) }
      end

      # Returns an array of the values of the first column in a select:
      #   select_values("SELECT id FROM companies LIMIT 3") => [1,2,3]
      def select_values(arel, name = nil, binds = [])
        select_rows(arel, name, binds).map(&:first)
      end

      # Returns an array of arrays containing the field values.
      # Order is the same as that returned by +columns+.
      def select_rows(arel, name = nil, binds = [], async: false)
        select_all(arel, name, binds, async: async).then(&:rows)
      end

      def query_value(...) # :nodoc:
        single_value_from_rows(query_rows(...))
      end

      def query_values(...) # :nodoc:
        query_rows(...).map(&:first)
      end

      def query_one(...) # :nodoc:
        query_all(...).first
      end

      def query_rows(...) # :nodoc:
        query_all(...).rows
      end

      def query_all(sql, name = "SCHEMA", allow_retry: true, materialize_transactions: false) # :nodoc:
        intent = internal_build_intent(sql, name, allow_retry:, materialize_transactions:)
        intent.execute!
        intent.cast_result
      end

      def query_command(sql, name = nil, allow_retry: false, materialize_transactions: true) # :nodoc:
        intent = internal_build_intent(sql, name, allow_retry: allow_retry, materialize_transactions: materialize_transactions)
        intent.execute!
        intent.finish
      end

      # Determines whether the SQL statement is a write query.
      def write_query?(sql)
        raise NotImplementedError
      end

      # Executes the SQL statement in the context of this connection and returns
      # the raw result from the connection adapter.
      #
      # Setting +allow_retry+ to true causes the db to reconnect and retry
      # executing the SQL statement in case of a connection-related exception.
      # This option should only be enabled for known idempotent queries.
      #
      # Note: the query is assumed to have side effects and the query cache
      # will be cleared. If the query is read-only, consider using #select_all
      # instead.
      #
      # Note: depending on your database connector, the result returned by this
      # method may be manually memory managed. Consider using #exec_query
      # wrapper instead.
      def execute(sql, name = nil, allow_retry: false)
        intent = internal_build_intent(sql, name, allow_retry: allow_retry)
        intent.execute!
        intent.raw_result
      end

      # Executes +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is logged along with
      # the executed +sql+ statement.
      #
      # Note: the query is assumed to have side effects and the query cache
      # will be cleared. If the query is read-only, consider using #select_all
      # instead.
      def exec_query(sql, name = "SQL", binds = [], prepare: false)
        intent = internal_build_intent(sql, name, binds, prepare: prepare)
        intent.execute!
        intent.cast_result
      end

      # Executes insert +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is logged along with
      # the executed +sql+ statement.
      # Some adapters support the `returning` keyword argument which allows to control the result of the query:
      # `nil` is the default value and maintains default behavior. If an array of column names is passed -
      # the result will contain values of the specified columns from the inserted row.
      def exec_insert(sql, name = nil, binds = [], pk = nil, sequence_name = nil, returning: nil)
        intent = QueryIntent.new(adapter: self, raw_sql: sql, name: name, binds: binds)

        _exec_insert(intent, pk, sequence_name, returning: returning)
      end

      def _exec_insert(intent, pk = nil, sequence_name = nil, returning: nil) # :nodoc:
        sql, binds = sql_for_insert(intent.raw_sql, pk, intent.binds, returning)
        intent.raw_sql = sql
        intent.binds = binds

        intent.execute!
        intent.cast_result
      end

      # Executes delete +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is logged along with
      # the executed +sql+ statement.
      def exec_delete(sql, name = nil, binds = [])
        intent = internal_build_intent(sql, name, binds)
        intent.execute!
        intent.affected_rows
      end

      # Executes update +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is logged along with
      # the executed +sql+ statement.
      def exec_update(sql, name = nil, binds = [])
        intent = internal_build_intent(sql, name, binds)
        intent.execute!
        intent.affected_rows
      end

      deprecate :exec_insert, :exec_delete, :exec_update, deprecator: ActiveRecord.deprecator

      def exec_insert_all(inserter, name) # :nodoc:
        intent = internal_build_intent(inserter.to_sql, name)
        intent.execute!
        intent.cast_result
      end

      def explain(arel, binds = [], options = []) # :nodoc:
        raise NotImplementedError
      end

      # Executes an INSERT query and returns the new record's ID
      #
      # +id_value+ will be returned unless the value is +nil+, in
      # which case the database will attempt to calculate the last inserted
      # id and return that value.
      #
      # If the next id was calculated in advance (as in Oracle), it should be
      # passed in as +id_value+.
      # Some adapters support the `returning` keyword argument which allows defining the return value of the method:
      # `nil` is the default value and maintains default behavior. If an array of column names is passed -
      # an array of is returned from the method representing values of the specified columns from the inserted row.
      def insert(arel, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [], returning: nil)
        intent = QueryIntent.new(adapter: self, arel: arel, name: name, binds: binds)

        value = _exec_insert(intent, pk, sequence_name, returning: returning)

        return returning_column_values(value) unless returning.nil?

        id_value || last_inserted_id(value)
      end
      alias create insert

      # Executes the update statement and returns the number of rows affected.
      def update(arel, name = nil, binds = [])
        intent = QueryIntent.new(adapter: self, arel: arel, name: name, binds: binds)

        intent.execute!
        intent.affected_rows
      end

      # Executes the delete statement and returns the number of rows affected.
      def delete(arel, name = nil, binds = [])
        intent = QueryIntent.new(adapter: self, arel: arel, name: name, binds: binds)

        intent.execute!
        intent.affected_rows
      end

      # Executes the truncate statement.
      def truncate(table_name, name = nil)
        execute(build_truncate_statement(table_name), name)
      end

      def truncate_tables(*table_names) # :nodoc:
        table_names -= [pool.schema_migration.table_name, pool.internal_metadata.table_name]

        return if table_names.empty?

        disable_referential_integrity do
          statements = build_truncate_statements(table_names)
          execute_batch(statements, "Truncate Tables")
        end
      end

      # Runs the given block in a database transaction, and returns the result
      # of the block.
      #
      # == Transaction callbacks
      #
      # #transaction yields an ActiveRecord::Transaction object on which it is
      # possible to register callback:
      #
      #   ActiveRecord::Base.transaction do |transaction|
      #     transaction.before_commit { puts "before commit!" }
      #     transaction.after_commit { puts "after commit!" }
      #     transaction.after_rollback { puts "after rollback!" }
      #   end
      #
      # == Nested transactions support
      #
      # #transaction calls can be nested. By default, this makes all database
      # statements in the nested transaction block become part of the parent
      # transaction. For example, the following behavior may be surprising:
      #
      #   ActiveRecord::Base.transaction do
      #     Post.create(title: 'first')
      #     ActiveRecord::Base.transaction do
      #       Post.create(title: 'second')
      #       raise ActiveRecord::Rollback
      #     end
      #   end
      #
      # This creates both "first" and "second" posts. Reason is the
      # ActiveRecord::Rollback exception in the nested block does not issue a
      # ROLLBACK. Since these exceptions are captured in transaction blocks,
      # the parent block does not see it and the real transaction is committed.
      #
      # Most databases don't support true nested transactions. At the time of
      # writing, the only database that supports true nested transactions that
      # we're aware of, is MS-SQL.
      #
      # In order to get around this problem, #transaction will emulate the effect
      # of nested transactions, by using savepoints:
      # https://dev.mysql.com/doc/refman/en/savepoint.html.
      #
      # It is safe to call this method if a database transaction is already open,
      # i.e. if #transaction is called within another #transaction block. In case
      # of a nested call, #transaction will behave as follows:
      #
      # - The block will be run without doing anything. All database statements
      #   that happen within the block are effectively appended to the already
      #   open database transaction.
      # - However, if +:requires_new+ is set, the block will be wrapped in a
      #   database savepoint acting as a sub-transaction.
      #
      # In order to get a ROLLBACK for the nested transaction you may ask for a
      # real sub-transaction by passing <tt>requires_new: true</tt>.
      # If anything goes wrong, the database rolls back to the beginning of
      # the sub-transaction without rolling back the parent transaction.
      # If we add it to the previous example:
      #
      #   ActiveRecord::Base.transaction do
      #     Post.create(title: 'first')
      #     ActiveRecord::Base.transaction(requires_new: true) do
      #       Post.create(title: 'second')
      #       raise ActiveRecord::Rollback
      #     end
      #   end
      #
      # only post with title "first" is created.
      #
      # See ActiveRecord::Transactions to learn more.
      #
      # === Caveats
      #
      # MySQL doesn't support DDL transactions. If you perform a DDL operation,
      # then any created savepoints will be automatically released. For example,
      # if you've created a savepoint, then you execute a CREATE TABLE statement,
      # then the savepoint that was created will be automatically released.
      #
      # This means that, on MySQL, you shouldn't execute DDL operations inside
      # a #transaction call that you know might create a savepoint. Otherwise,
      # #transaction will raise exceptions when it tries to release the
      # already-automatically-released savepoints:
      #
      #   Model.lease_connection.transaction do  # BEGIN
      #     Model.lease_connection.transaction(requires_new: true) do  # CREATE SAVEPOINT active_record_1
      #       Model.lease_connection.create_table(...)
      #       # active_record_1 now automatically released
      #     end  # RELEASE SAVEPOINT active_record_1  <--- BOOM! database error!
      #   end
      #
      # == Transaction isolation
      #
      # If your database supports setting the isolation level for a transaction, you can set
      # it like so:
      #
      #   Post.transaction(isolation: :serializable) do
      #     # ...
      #   end
      #
      # Valid isolation levels are:
      #
      # * <tt>:read_uncommitted</tt>
      # * <tt>:read_committed</tt>
      # * <tt>:repeatable_read</tt>
      # * <tt>:serializable</tt>
      #
      # You should consult the documentation for your database to understand the
      # semantics of these different levels:
      #
      # * https://www.postgresql.org/docs/current/static/transaction-iso.html
      # * https://dev.mysql.com/doc/refman/en/set-transaction.html
      #
      # An ActiveRecord::TransactionIsolationError will be raised if:
      #
      # * The adapter does not support setting the isolation level
      # * You are joining an existing open transaction
      # * You are creating a nested (savepoint) transaction
      #
      # The mysql2, trilogy, and postgresql adapters support setting the transaction
      # isolation level.
      #  :args: (requires_new: nil, isolation: nil, &block)
      def transaction(requires_new: nil, isolation: nil, joinable: true, &block)
        # If we're running inside the single, non-joinable transaction that
        # ActiveRecord::TestFixtures starts around each example (depth == 1),
        # an `isolation:` hint must be validated then ignored so that the
        # adapter isn't asked to change the isolation level mid-transaction.
        isolation_override = false
        if isolation && open_transactions == 1 && !current_transaction.joinable?
          iso = isolation.to_sym

          unless transaction_isolation_levels.include?(iso)
            raise ActiveRecord::TransactionIsolationError,
                  "invalid transaction isolation level: #{iso.inspect}"
          end

          isolation_override = true
          old_isolation = current_transaction.isolation
          current_transaction.isolation = iso
          isolation = nil
        end

        if !requires_new && current_transaction.joinable?
          if isolation && current_transaction.isolation != isolation
            raise ActiveRecord::TransactionIsolationError, "cannot set isolation when joining a transaction"
          end
          yield current_transaction.user_transaction
        else
          within_new_transaction(isolation: isolation, joinable: joinable, &block)
        end
      rescue ActiveRecord::Rollback
        # rollbacks are silently swallowed
      ensure
        current_transaction.isolation = old_isolation if isolation_override
      end

      attr_reader :transaction_manager # :nodoc:

      delegate :within_new_transaction, :open_transactions, :current_transaction, :begin_transaction,
               :commit_transaction, :rollback_transaction, :materialize_transactions,
               :disable_lazy_transactions!, :enable_lazy_transactions!, :dirty_current_transaction,
               to: :transaction_manager

      def transaction_open?
        current_transaction.open?
      end

      def reset_transaction(restore: false) # :nodoc:
        # Store the existing transaction state to the side
        old_state = @transaction_manager if restore && @transaction_manager&.restorable?

        @transaction_manager = ConnectionAdapters::TransactionManager.new(self)

        if block_given?
          # Reconfigure the connection without any transaction state in the way
          result = yield

          # Now the connection's fully established, we can swap back
          if old_state
            @transaction_manager = old_state
            @transaction_manager.restore_transactions
          end

          result
        end
      end

      # Register a record with the current transaction so that its after_commit and after_rollback callbacks
      # can be called.
      def add_transaction_record(record, ensure_finalize = true)
        current_transaction.add_record(record, ensure_finalize)
      end

      # Begins the transaction (and turns off auto-committing).
      def begin_db_transaction()    end

      def begin_deferred_transaction(isolation_level = nil) # :nodoc:
        if isolation_level
          begin_isolated_db_transaction(isolation_level)
        else
          begin_db_transaction
        end
      end

      TRANSACTION_ISOLATION_LEVELS = {
        read_uncommitted: "READ UNCOMMITTED",
        read_committed:   "READ COMMITTED",
        repeatable_read:  "REPEATABLE READ",
        serializable:     "SERIALIZABLE"
      }.freeze
      private_constant :TRANSACTION_ISOLATION_LEVELS

      def transaction_isolation_levels
        TRANSACTION_ISOLATION_LEVELS
      end

      # Begins the transaction with the isolation level set. Raises an error by
      # default; adapters that support setting the isolation level should implement
      # this method.
      def begin_isolated_db_transaction(isolation)
        raise ActiveRecord::TransactionIsolationError, "adapter does not support setting transaction isolation"
      end

      # Hook point called after an isolated DB transaction is committed
      # or rolled back.
      # Most adapters don't need to implement anything because the isolation
      # level is set on a per transaction basis.
      # But some databases like SQLite set it on a per connection level
      # and need to explicitly reset it after commit or rollback.
      def reset_isolation_level
      end

      # Commits the transaction (and turns on auto-committing).
      def commit_db_transaction()   end

      # Rolls back the transaction (and turns on auto-committing). Must be
      # done if the transaction block raises an exception or returns false.
      def rollback_db_transaction
        exec_rollback_db_transaction
      rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed
        # Connection's gone; that counts as a rollback
      end

      def exec_rollback_db_transaction() end # :nodoc:

      def restart_db_transaction
        exec_restart_db_transaction
      end

      def exec_restart_db_transaction() end # :nodoc:

      def rollback_to_savepoint(name = nil)
        exec_rollback_to_savepoint(name)
      end

      def default_sequence_name(table, column)
        nil
      end

      # Set the sequence to the max value of the table's column.
      def reset_sequence!(table, column, sequence = nil)
        # Do nothing by default. Implement for PostgreSQL, Oracle, ...
      end

      # Inserts the given fixture into the table. Overridden in adapters that require
      # something beyond a simple insert (e.g. Oracle).
      # Most of adapters should implement +insert_fixtures_set+ that leverages bulk SQL insert.
      # We keep this method to provide fallback
      # for databases like SQLite that do not support bulk inserts.
      def insert_fixture(fixture, table_name)
        execute(build_fixture_sql(Array.wrap(fixture), table_name), "Fixture Insert")
      end

      def insert_fixtures_set(fixture_set, tables_to_delete = [])
        fixture_inserts = build_fixture_statements(fixture_set)
        table_deletes = build_delete_from_statements(tables_to_delete)
        statements = table_deletes + fixture_inserts

        transaction(requires_new: true) do
          disable_referential_integrity do
            execute_batch(statements, "Fixtures Load")
          end
        end
      end

      def empty_all_tables # :nodoc:
        truncate_tables(*tables)
      end

      def empty_insert_statement_value(primary_key = nil)
        "DEFAULT VALUES"
      end

      # Fixture value is quoted by Arel, however scalar values
      # are not quotable. In this case we want to convert
      # the column value to YAML.
      def with_yaml_fallback(value) # :nodoc:
        if value.is_a?(Hash) || value.is_a?(Array)
          YAML.dump(value)
        else
          value
        end
      end

      # This is a safe default, even if not high precision on all databases
      HIGH_PRECISION_CURRENT_TIMESTAMP = Arel.sql("CURRENT_TIMESTAMP", retryable: true).freeze # :nodoc:
      private_constant :HIGH_PRECISION_CURRENT_TIMESTAMP

      # Returns an Arel SQL literal for the CURRENT_TIMESTAMP for usage with
      # arbitrary precision date/time columns.
      #
      # Adapters supporting datetime with precision should override this to
      # provide as much precision as is available.
      def high_precision_current_timestamp
        HIGH_PRECISION_CURRENT_TIMESTAMP
      end

      def default_insert_value(column) # :nodoc:
        DEFAULT_INSERT_VALUE
      end

      # Lowest-level abstract execution of a query, called only from the intent itself.
      # Final wrapper around the subclass-specific +perform_query+. Populates the calling
      # intent's raw_result.
      def execute_intent(intent) # :nodoc:
        should_dirty = false

        if intent.materialize_transactions
          # These can raise locally (e.g., ReadOnlyError). Validate before BEGIN.
          intent.processed_sql
          intent.type_casted_binds
          materialize_transactions
        end

        log(intent) do |notification_payload|
          intent.notification_payload = notification_payload
          with_raw_connection(allow_retry: intent.allow_retry, materialize_transactions: false) do |conn|
            should_dirty = intent.materialize_transactions
            result = perform_query(conn, intent)
            intent.raw_result = result
            handle_warnings(result, intent.processed_sql)
          end
        end
      ensure
        dirty_current_transaction if should_dirty
      end

      # Executes SQL statements in the context of this connection without
      # returning a result.
      def execute_batch(statements, name = nil, **kwargs) # :nodoc:
        statements.each do |statement|
          intent = QueryIntent.new(
            adapter: self,
            processed_sql: statement,
            name: name,
            binds: kwargs[:binds] || [],
            prepare: kwargs[:prepare] || false,
            allow_retry: kwargs[:allow_retry] || false,
            materialize_transactions: kwargs[:materialize_transactions] != false,
            batch: kwargs[:batch] || false
          )
          intent.execute!
          intent.finish
        end
      end

      private
        DEFAULT_INSERT_VALUE = Arel.sql("DEFAULT").freeze
        private_constant :DEFAULT_INSERT_VALUE

        def perform_query(raw_connection, intent)
          raise NotImplementedError
        end

        def handle_warnings(raw_result, sql)
        end

        # Receive a native adapter result object and returns an ActiveRecord::Result object.
        def cast_result(raw_result)
          raise NotImplementedError
        end

        def affected_rows(raw_result)
          raise NotImplementedError
        end

        def internal_build_intent(sql, name = "SQL", binds = [], prepare: false, allow_retry: false, materialize_transactions: true, &block)
          QueryIntent.new(
            adapter: self,
            raw_sql: sql,
            name: name,
            binds: binds,
            prepare: prepare,
            allow_retry: allow_retry,
            materialize_transactions: materialize_transactions
          )
        end

        def build_fixture_sql(fixtures, table_name)
          columns = schema_cache.columns_hash(table_name).reject { |_, column| supports_virtual_columns? && column.virtual? }

          values_list = fixtures.map do |fixture|
            fixture = fixture.stringify_keys

            unknown_columns = fixture.keys - columns.keys
            if unknown_columns.any?
              raise Fixture::FixtureError, %(table "#{table_name}" has no columns named #{unknown_columns.map(&:inspect).join(', ')}.)
            end

            columns.map do |name, column|
              if fixture.key?(name)
                with_yaml_fallback(column.cast_type.serialize(fixture[name]))
              else
                default_insert_value(column)
              end
            end
          end

          table = Arel::Table.new(table_name)
          manager = Arel::InsertManager.new(table)

          if values_list.size == 1
            values = values_list.shift
            new_values = []
            columns.each_key.with_index { |column, i|
              unless values[i].equal?(DEFAULT_INSERT_VALUE)
                new_values << values[i]
                manager.columns << table[column]
              end
            }
            values_list << new_values
          else
            columns.each_key { |column| manager.columns << table[column] }
          end

          manager.values = manager.create_values_list(values_list)
          visitor.compile(manager.ast)
        end

        def build_fixture_statements(fixture_set)
          fixture_set.filter_map do |table_name, fixtures|
            next if fixtures.empty?
            build_fixture_sql(fixtures, table_name)
          end
        end

        def build_truncate_statement(table_name)
          "TRUNCATE TABLE #{quote_table_name(table_name)}"
        end

        def build_truncate_statements(table_names)
          table_names.map do |table_name|
            build_truncate_statement(table_name)
          end
        end

        def build_delete_from_statements(table_names)
          table_names.map do |table_name|
            "DELETE FROM #{quote_table_name(table_name)}"
          end
        end

        def combine_multi_statements(total_sql)
          total_sql.join(";\n")
        end

        def sql_for_insert(sql, pk, binds, returning) # :nodoc:
          if supports_insert_returning?
            if pk.nil?
              # Extract the table from the insert sql. Yuck.
              table_ref = extract_table_ref_from_insert_sql(sql)
              pk = schema_cache.primary_keys(table_ref) if table_ref
            end

            returning_columns = returning || Array(pk)

            returning_columns_statement = returning_columns.map { |c| quote_column_name(c) }.join(", ")
            sql = "#{sql} RETURNING #{returning_columns_statement}" if returning_columns.any?
          end

          [sql, binds]
        end

        def last_inserted_id(result)
          single_value_from_rows(result.rows)
        end

        def returning_column_values(result)
          [last_inserted_id(result)]
        end

        def single_value_from_rows(rows)
          row = rows.first
          row && row.first
        end

        def arel_from_relation(relation)
          if relation.is_a?(Relation)
            relation.arel
          else
            relation
          end
        end

        def extract_table_ref_from_insert_sql(sql)
          if sql =~ /into\s("[-A-Za-z0-9_."\[\]\s]+"|[A-Za-z0-9_."\[\]]+)\s*/im
            $1.delete('"').strip
          end
        end
    end
  end
end
