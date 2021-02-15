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

      def to_sql_and_binds(arel_or_sql_string, binds = [], preparable = nil) # :nodoc:
        if arel_or_sql_string.respond_to?(:ast)
          unless binds.empty?
            raise "Passing bind parameters with an arel AST is forbidden. " \
              "The values must be stored on the AST directly"
          end

          collector = collector()

          if prepared_statements
            collector.preparable = true
            sql, binds = visitor.compile(arel_or_sql_string.ast, collector)

            if binds.length > bind_params_length
              unprepared_statement do
                return to_sql_and_binds(arel_or_sql_string)
              end
            end
            preparable = collector.preparable
          else
            sql = visitor.compile(arel_or_sql_string.ast, collector)
          end
          [sql.freeze, binds, preparable]
        else
          arel_or_sql_string = arel_or_sql_string.dup.freeze unless arel_or_sql_string.frozen?
          [arel_or_sql_string, binds, preparable]
        end
      end
      private :to_sql_and_binds

      # This is used in the StatementCache object. It returns an object that
      # can be used to query the database repeatedly.
      def cacheable_query(klass, arel) # :nodoc:
        if prepared_statements
          sql, binds = visitor.compile(arel.ast, collector)
          query = klass.query(sql)
        else
          collector = klass.partial_query_collector
          parts, binds = visitor.compile(arel.ast, collector)
          query = klass.partial_query(parts)
        end
        [query, binds]
      end

      # Returns an ActiveRecord::Result instance.
      def select_all(arel, name = nil, binds = [], preparable: nil)
        arel = arel_from_relation(arel)
        sql, binds, preparable = to_sql_and_binds(arel, binds, preparable)

        if prepared_statements && preparable
          select_prepared(sql, name, binds)
        else
          select(sql, name, binds)
        end
      rescue ::RangeError
        ActiveRecord::Result.new([], [])
      end

      # Returns a record hash with the column names as keys and column values
      # as values.
      def select_one(arel, name = nil, binds = [])
        select_all(arel, name, binds).first
      end

      # Returns a single value from a record
      def select_value(arel, name = nil, binds = [])
        single_value_from_rows(select_rows(arel, name, binds))
      end

      # Returns an array of the values of the first column in a select:
      #   select_values("SELECT id FROM companies LIMIT 3") => [1,2,3]
      def select_values(arel, name = nil, binds = [])
        select_rows(arel, name, binds).map(&:first)
      end

      # Returns an array of arrays containing the field values.
      # Order is the same as that returned by +columns+.
      def select_rows(arel, name = nil, binds = [])
        select_all(arel, name, binds).rows
      end

      def query_value(sql, name = nil) # :nodoc:
        single_value_from_rows(query(sql, name))
      end

      def query_values(sql, name = nil) # :nodoc:
        query(sql, name).map(&:first)
      end

      def query(sql, name = nil) # :nodoc:
        exec_query(sql, name).rows
      end

      # Determines whether the SQL statement is a write query.
      def write_query?(sql)
        raise NotImplementedError
      end

      # Executes the SQL statement in the context of this connection and returns
      # the raw result from the connection adapter.
      # Note: depending on your database connector, the result returned by this
      # method may be manually memory managed. Consider using the exec_query
      # wrapper instead.
      def execute(sql, name = nil)
        raise NotImplementedError
      end

      # Executes +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is logged along with
      # the executed +sql+ statement.
      def exec_query(sql, name = "SQL", binds = [], prepare: false)
        raise NotImplementedError
      end

      # Executes insert +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is logged along with
      # the executed +sql+ statement.
      def exec_insert(sql, name = nil, binds = [], pk = nil, sequence_name = nil)
        sql, binds = sql_for_insert(sql, pk, binds)
        exec_query(sql, name, binds)
      end

      # Executes delete +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is logged along with
      # the executed +sql+ statement.
      def exec_delete(sql, name = nil, binds = [])
        exec_query(sql, name, binds)
      end

      # Executes update +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is logged along with
      # the executed +sql+ statement.
      def exec_update(sql, name = nil, binds = [])
        exec_query(sql, name, binds)
      end

      def exec_insert_all(sql, name) # :nodoc:
        exec_query(sql, name)
      end

      def explain(arel, binds = []) # :nodoc:
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
      def insert(arel, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])
        sql, binds = to_sql_and_binds(arel, binds)
        value = exec_insert(sql, name, binds, pk, sequence_name)
        id_value || last_inserted_id(value)
      end
      alias create insert

      # Executes the update statement and returns the number of rows affected.
      def update(arel, name = nil, binds = [])
        sql, binds = to_sql_and_binds(arel, binds)
        exec_update(sql, name, binds)
      end

      # Executes the delete statement and returns the number of rows affected.
      def delete(arel, name = nil, binds = [])
        sql, binds = to_sql_and_binds(arel, binds)
        exec_delete(sql, name, binds)
      end

      # Executes the truncate statement.
      def truncate(table_name, name = nil)
        execute(build_truncate_statement(table_name), name)
      end

      def truncate_tables(*table_names) # :nodoc:
        table_names -= [schema_migration.table_name, InternalMetadata.table_name]

        return if table_names.empty?

        with_multi_statements do
          disable_referential_integrity do
            statements = build_truncate_statements(table_names)
            execute_batch(statements, "Truncate Tables")
          end
        end
      end

      # Runs the given block in a database transaction, and returns the result
      # of the block.
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
      #   Model.connection.transaction do  # BEGIN
      #     Model.connection.transaction(requires_new: true) do  # CREATE SAVEPOINT active_record_1
      #       Model.connection.create_table(...)
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
      # The mysql2 and postgresql adapters support setting the transaction
      # isolation level.
      def transaction(requires_new: nil, isolation: nil, joinable: true)
        if !requires_new && current_transaction.joinable?
          if isolation
            raise ActiveRecord::TransactionIsolationError, "cannot set isolation when joining a transaction"
          end
          yield
        else
          transaction_manager.within_new_transaction(isolation: isolation, joinable: joinable) { yield }
        end
      rescue ActiveRecord::Rollback
        # rollbacks are silently swallowed
      end

      attr_reader :transaction_manager #:nodoc:

      delegate :within_new_transaction, :open_transactions, :current_transaction, :begin_transaction,
               :commit_transaction, :rollback_transaction, :materialize_transactions,
               :disable_lazy_transactions!, :enable_lazy_transactions!, to: :transaction_manager

      def mark_transaction_written_if_write(sql) # :nodoc:
        transaction = current_transaction
        if transaction.open?
          transaction.written ||= write_query?(sql)
        end
      end

      def transaction_open?
        current_transaction.open?
      end

      def reset_transaction #:nodoc:
        @transaction_manager = ConnectionAdapters::TransactionManager.new(self)
      end

      # Register a record with the current transaction so that its after_commit and after_rollback callbacks
      # can be called.
      def add_transaction_record(record, ensure_finalize = true)
        current_transaction.add_record(record, ensure_finalize)
      end

      # Begins the transaction (and turns off auto-committing).
      def begin_db_transaction()    end

      def transaction_isolation_levels
        {
          read_uncommitted: "READ UNCOMMITTED",
          read_committed:   "READ COMMITTED",
          repeatable_read:  "REPEATABLE READ",
          serializable:     "SERIALIZABLE"
        }
      end

      # Begins the transaction with the isolation level set. Raises an error by
      # default; adapters that support setting the isolation level should implement
      # this method.
      def begin_isolated_db_transaction(isolation)
        raise ActiveRecord::TransactionIsolationError, "adapter does not support setting transaction isolation"
      end

      # Commits the transaction (and turns on auto-committing).
      def commit_db_transaction()   end

      # Rolls back the transaction (and turns on auto-committing). Must be
      # done if the transaction block raises an exception or returns false.
      def rollback_db_transaction
        exec_rollback_db_transaction
      end

      def exec_rollback_db_transaction() end #:nodoc:

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
      # for databases like sqlite that do not support bulk inserts.
      def insert_fixture(fixture, table_name)
        execute(build_fixture_sql(Array.wrap(fixture), table_name), "Fixture Insert")
      end

      def insert_fixtures_set(fixture_set, tables_to_delete = [])
        fixture_inserts = build_fixture_statements(fixture_set)
        table_deletes = tables_to_delete.map { |table| "DELETE FROM #{quote_table_name(table)}" }
        statements = table_deletes + fixture_inserts

        with_multi_statements do
          disable_referential_integrity do
            transaction(requires_new: true) do
              execute_batch(statements, "Fixtures Load")
            end
          end
        end
      end

      def empty_insert_statement_value(primary_key = nil)
        "DEFAULT VALUES"
      end

      # Sanitizes the given LIMIT parameter in order to prevent SQL injection.
      #
      # The +limit+ may be anything that can evaluate to a string via #to_s. It
      # should look like an integer, or an Arel SQL literal.
      #
      # Returns Integer and Arel::Nodes::SqlLiteral limits as is.
      def sanitize_limit(limit)
        if limit.is_a?(Integer) || limit.is_a?(Arel::Nodes::SqlLiteral)
          limit
        else
          Integer(limit)
        end
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

      private
        def execute_batch(statements, name = nil)
          statements.each do |statement|
            execute(statement, name)
          end
        end

        DEFAULT_INSERT_VALUE = Arel.sql("DEFAULT").freeze
        private_constant :DEFAULT_INSERT_VALUE

        def default_insert_value(column)
          DEFAULT_INSERT_VALUE
        end

        def build_fixture_sql(fixtures, table_name)
          columns = schema_cache.columns_hash(table_name)

          values_list = fixtures.map do |fixture|
            fixture = fixture.stringify_keys

            unknown_columns = fixture.keys - columns.keys
            if unknown_columns.any?
              raise Fixture::FixtureError, %(table "#{table_name}" has no columns named #{unknown_columns.map(&:inspect).join(', ')}.)
            end

            columns.map do |name, column|
              if fixture.key?(name)
                type = lookup_cast_type_from_column(column)
                with_yaml_fallback(type.serialize(fixture[name]))
              else
                default_insert_value(column)
              end
            end
          end

          table = Arel::Table.new(table_name)
          manager = Arel::InsertManager.new
          manager.into(table)

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
          fixture_set.map do |table_name, fixtures|
            next if fixtures.empty?
            build_fixture_sql(fixtures, table_name)
          end.compact
        end

        def build_truncate_statement(table_name)
          "TRUNCATE TABLE #{quote_table_name(table_name)}"
        end

        def build_truncate_statements(table_names)
          table_names.map do |table_name|
            build_truncate_statement(table_name)
          end
        end

        def with_multi_statements
          yield
        end

        def combine_multi_statements(total_sql)
          total_sql.join(";\n")
        end

        # Returns an ActiveRecord::Result instance.
        def select(sql, name = nil, binds = [])
          exec_query(sql, name, binds, prepare: false)
        end

        def select_prepared(sql, name = nil, binds = [])
          exec_query(sql, name, binds, prepare: true)
        end

        def sql_for_insert(sql, pk, binds)
          [sql, binds]
        end

        def last_inserted_id(result)
          single_value_from_rows(result.rows)
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
    end
  end
end
