module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module DatabaseStatements
      def initialize
        super
        reset_transaction
      end

      # Converts an arel AST to SQL
      def to_sql(arel, binds = [])
        if arel.respond_to?(:ast)
          collected = visitor.accept(arel.ast, collector)
          collected.compile(binds.dup, self)
        else
          arel
        end
      end

      # This is used in the StatementCache object. It returns an object that
      # can be used to query the database repeatedly.
      def cacheable_query(arel) # :nodoc:
        if prepared_statements
          ActiveRecord::StatementCache.query visitor, arel.ast
        else
          ActiveRecord::StatementCache.partial_query visitor, arel.ast, collector
        end
      end

      # Returns an ActiveRecord::Result instance.
      def select_all(arel, name = nil, binds = [], preparable: nil)
        arel, binds = binds_from_relation arel, binds
        sql = to_sql(arel, binds)
        if !prepared_statements || (arel.is_a?(String) && preparable.nil?)
          preparable = false
        else
          preparable = visitor.preparable
        end
        if prepared_statements && preparable
          select_prepared(sql, name, binds)
        else
          select(sql, name, binds)
        end
      end

      # Returns a record hash with the column names as keys and column values
      # as values.
      def select_one(arel, name = nil, binds = [])
        select_all(arel, name, binds).first
      end

      # Returns a single value from a record
      def select_value(arel, name = nil, binds = [])
        arel, binds = binds_from_relation arel, binds
        if result = select_rows(to_sql(arel, binds), name, binds).first
          result.first
        end
      end

      # Returns an array of the values of the first column in a select:
      #   select_values("SELECT id FROM companies LIMIT 3") => [1,2,3]
      def select_values(arel, name = nil, binds = [])
        arel, binds = binds_from_relation arel, binds
        select_rows(to_sql(arel, binds), name, binds).map(&:first)
      end

      # Returns an array of arrays containing the field values.
      # Order is the same as that returned by +columns+.
      def select_rows(sql, name = nil, binds = [])
        exec_query(sql, name, binds).rows
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
      def exec_query(sql, name = 'SQL', binds = [], prepare: false)
        raise NotImplementedError
      end

      # Executes insert +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is logged along with
      # the executed +sql+ statement.
      def exec_insert(sql, name, binds, pk = nil, sequence_name = nil)
        exec_query(sql, name, binds)
      end

      # Executes delete +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is logged along with
      # the executed +sql+ statement.
      def exec_delete(sql, name, binds)
        exec_query(sql, name, binds)
      end

      # Executes the truncate statement.
      def truncate(table_name, name = nil)
        raise NotImplementedError
      end

      # Executes update +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is logged along with
      # the executed +sql+ statement.
      def exec_update(sql, name, binds)
        exec_query(sql, name, binds)
      end

      # Executes an INSERT query and returns the new record's ID
      #
      # +id_value+ will be returned unless the value is nil, in
      # which case the database will attempt to calculate the last inserted
      # id and return that value.
      #
      # If the next id was calculated in advance (as in Oracle), it should be
      # passed in as +id_value+.
      def insert(arel, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])
        sql, binds, pk, sequence_name = sql_for_insert(to_sql(arel, binds), pk, id_value, sequence_name, binds)
        value = exec_insert(sql, name, binds, pk, sequence_name)
        id_value || last_inserted_id(value)
      end
      alias create insert
      alias insert_sql insert
      deprecate insert_sql: :insert

      # Executes the update statement and returns the number of rows affected.
      def update(arel, name = nil, binds = [])
        exec_update(to_sql(arel, binds), name, binds)
      end
      alias update_sql update
      deprecate update_sql: :update

      # Executes the delete statement and returns the number of rows affected.
      def delete(arel, name = nil, binds = [])
        exec_delete(to_sql(arel, binds), name, binds)
      end
      alias delete_sql delete
      deprecate delete_sql: :delete

      # Returns +true+ when the connection adapter supports prepared statement
      # caching, otherwise returns +false+
      def supports_statement_cache?
        false
      end

      # Runs the given block in a database transaction, and returns the result
      # of the block.
      #
      # == Nested transactions support
      #
      # Most databases don't support true nested transactions. At the time of
      # writing, the only database that supports true nested transactions that
      # we're aware of, is MS-SQL.
      #
      # In order to get around this problem, #transaction will emulate the effect
      # of nested transactions, by using savepoints:
      # http://dev.mysql.com/doc/refman/5.7/en/savepoint.html
      # Savepoints are supported by MySQL and PostgreSQL. SQLite3 version >= '3.6.8'
      # supports savepoints.
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
      # * http://www.postgresql.org/docs/current/static/transaction-iso.html
      # * https://dev.mysql.com/doc/refman/5.7/en/set-transaction.html
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

      delegate :within_new_transaction, :open_transactions, :current_transaction, :begin_transaction, :commit_transaction, :rollback_transaction, to: :transaction_manager

      def transaction_open?
        current_transaction.open?
      end

      def reset_transaction #:nodoc:
        @transaction_manager = ConnectionAdapters::TransactionManager.new(self)
      end

      # Register a record with the current transaction so that its after_commit and after_rollback callbacks
      # can be called.
      def add_transaction_record(record)
        current_transaction.add_record(record)
      end

      def transaction_state
        current_transaction.state
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
      # something beyond a simple insert (eg. Oracle).
      def insert_fixture(fixture, table_name)
        fixture = fixture.stringify_keys

        columns = schema_cache.columns_hash(table_name)
        binds = fixture.map do |name, value|
          if column = columns[name]
            type = lookup_cast_type_from_column(column)
            Relation::QueryAttribute.new(name, value, type)
          else
            raise Fixture::FixtureError, %(table "#{table_name}" has no column named #{name.inspect}.)
          end
        end
        key_list = fixture.keys.map { |name| quote_column_name(name) }
        value_list = prepare_binds_for_database(binds).map do |value|
          begin
            quote(value)
          rescue TypeError
            quote(YAML.dump(value))
          end
        end

        execute "INSERT INTO #{quote_table_name(table_name)} (#{key_list.join(', ')}) VALUES (#{value_list.join(', ')})", 'Fixture Insert'
      end

      def empty_insert_statement_value
        "DEFAULT VALUES"
      end

      # Sanitizes the given LIMIT parameter in order to prevent SQL injection.
      #
      # The +limit+ may be anything that can evaluate to a string via #to_s. It
      # should look like an integer, or a comma-delimited list of integers, or
      # an Arel SQL literal.
      #
      # Returns Integer and Arel::Nodes::SqlLiteral limits as is.
      # Returns the sanitized limit parameter, either as an integer, or as a
      # string which contains a comma-delimited list of integers.
      def sanitize_limit(limit)
        if limit.is_a?(Integer) || limit.is_a?(Arel::Nodes::SqlLiteral)
          limit
        elsif limit.to_s.include?(',')
          Arel.sql limit.to_s.split(',').map{ |i| Integer(i) }.join(',')
        else
          Integer(limit)
        end
      end

      # The default strategy for an UPDATE with joins is to use a subquery. This doesn't work
      # on MySQL (even when aliasing the tables), but MySQL allows using JOIN directly in
      # an UPDATE statement, so in the MySQL adapters we redefine this to do that.
      def join_to_update(update, select, key) # :nodoc:
        subselect = subquery_for(key, select)

        update.where key.in(subselect)
      end
      alias join_to_delete join_to_update

      protected

        # Returns a subquery for the given key using the join information.
        def subquery_for(key, select)
          subselect = select.clone
          subselect.projections = [key]
          subselect
        end

        # Returns an ActiveRecord::Result instance.
        def select(sql, name = nil, binds = [])
          exec_query(sql, name, binds, prepare: false)
        end

        def select_prepared(sql, name = nil, binds = [])
          exec_query(sql, name, binds, prepare: true)
        end

        def sql_for_insert(sql, pk, id_value, sequence_name, binds)
          [sql, binds, pk, sequence_name]
        end

        def last_inserted_id(result)
          row = result.rows.first
          row && row.first
        end

        def binds_from_relation(relation, binds)
          if relation.is_a?(Relation) && binds.empty?
            relation, binds = relation.arel, relation.bound_attributes
          end
          [relation, binds]
        end
    end
  end
end
