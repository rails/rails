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
          binds = binds.dup
          visitor.accept(arel.ast) do
            quote(*binds.shift.reverse)
          end
        else
          arel
        end
      end

      # Returns an array of record hashes with the column names as keys and
      # column values as values.
      def select_all(arel, name = nil, binds = [])
        select(to_sql(arel, binds), name, binds)
      end

      # Returns a record hash with the column names as keys and column values
      # as values.
      def select_one(arel, name = nil, binds = [])
        result = select_all(arel, name, binds)
        result.first if result
      end

      # Returns a single value from a record
      def select_value(arel, name = nil, binds = [])
        if result = select_one(arel, name, binds)
          result.values.first
        end
      end

      # Returns an array of the values of the first column in a select:
      #   select_values("SELECT id FROM companies LIMIT 3") => [1,2,3]
      def select_values(arel, name = nil)
        result = select_rows(to_sql(arel, []), name)
        result.map { |v| v[0] }
      end

      # Returns an array of arrays containing the field values.
      # Order is the same as that returned by +columns+.
      def select_rows(sql, name = nil)
      end
      undef_method :select_rows

      # Executes the SQL statement in the context of this connection.
      def execute(sql, name = nil)
      end
      undef_method :execute

      # Executes +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is logged along with
      # the executed +sql+ statement.
      def exec_query(sql, name = 'SQL', binds = [])
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

      # Executes update +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is logged along with
      # the executed +sql+ statement.
      def exec_update(sql, name, binds)
        exec_query(sql, name, binds)
      end

      # Returns the last auto-generated ID from the affected table.
      #
      # +id_value+ will be returned unless the value is nil, in
      # which case the database will attempt to calculate the last inserted
      # id and return that value.
      #
      # If the next id was calculated in advance (as in Oracle), it should be
      # passed in as +id_value+.
      def insert(arel, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])
        sql, binds = sql_for_insert(to_sql(arel, binds), pk, id_value, sequence_name, binds)
        value      = exec_insert(sql, name, binds, pk, sequence_name)
        id_value || last_inserted_id(value)
      end

      # Executes the update statement and returns the number of rows affected.
      def update(arel, name = nil, binds = [])
        exec_update(to_sql(arel, binds), name, binds)
      end

      # Executes the delete statement and returns the number of rows affected.
      def delete(arel, name = nil, binds = [])
        exec_delete(to_sql(arel, binds), name, binds)
      end

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
      # http://dev.mysql.com/doc/refman/5.0/en/savepoint.html
      # Savepoints are supported by MySQL and PostgreSQL, but not SQLite3.
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
      # * http://www.postgresql.org/docs/9.1/static/transaction-iso.html
      # * https://dev.mysql.com/doc/refman/5.0/en/set-transaction.html
      #
      # An <tt>ActiveRecord::TransactionIsolationError</tt> will be raised if:
      #
      # * The adapter does not support setting the isolation level
      # * You are joining an existing open transaction
      # * You are creating a nested (savepoint) transaction
      #
      # The mysql, mysql2 and postgresql adapters support setting the transaction
      # isolation level. However, support is disabled for mysql versions below 5,
      # because they are affected by a bug[http://bugs.mysql.com/bug.php?id=39170]
      # which means the isolation level gets persisted outside the transaction.
      def transaction(options = {})
        options.assert_valid_keys :requires_new, :joinable, :isolation

        if !options[:requires_new] && current_transaction.joinable?
          if options[:isolation]
            raise ActiveRecord::TransactionIsolationError, "cannot set isolation when joining a transaction"
          end

          yield
        else
          within_new_transaction(options) { yield }
        end
      rescue ActiveRecord::Rollback
        # rollbacks are silently swallowed
      end

      def within_new_transaction(options = {}) #:nodoc:
        transaction = begin_transaction(options)
        yield
      rescue Exception => error
        rollback_transaction if transaction
        raise
      ensure
        begin
          commit_transaction unless error
        rescue Exception
          rollback_transaction
          raise
        end
      end

      def current_transaction #:nodoc:
        @transaction
      end

      def transaction_open?
        @transaction.open?
      end

      def begin_transaction(options = {}) #:nodoc:
        @transaction = @transaction.begin(options)
      end

      def commit_transaction #:nodoc:
        @transaction = @transaction.commit
      end

      def rollback_transaction #:nodoc:
        @transaction = @transaction.rollback
      end

      def reset_transaction #:nodoc:
        @transaction = ClosedTransaction.new(self)
      end

      # Register a record with the current transaction so that its after_commit and after_rollback callbacks
      # can be called.
      def add_transaction_record(record)
        @transaction.add_record(record)
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
      def rollback_db_transaction() end

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
        columns = schema_cache.columns_hash(table_name)

        key_list   = []
        value_list = fixture.map do |name, value|
          key_list << quote_column_name(name)
          quote(value, columns[name])
        end

        execute "INSERT INTO #{quote_table_name(table_name)} (#{key_list.join(', ')}) VALUES (#{value_list.join(', ')})", 'Fixture Insert'
      end

      def empty_insert_statement_value
        "DEFAULT VALUES"
      end

      def case_sensitive_equality_operator
        "="
      end

      def limited_update_conditions(where_sql, quoted_table_name, quoted_primary_key)
        "WHERE #{quoted_primary_key} IN (SELECT #{quoted_primary_key} FROM #{quoted_table_name} #{where_sql})"
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
        elsif limit.to_s =~ /,/
          Arel.sql limit.to_s.split(',').map{ |i| Integer(i) }.join(',')
        else
          Integer(limit)
        end
      end

      # The default strategy for an UPDATE with joins is to use a subquery. This doesn't work
      # on mysql (even when aliasing the tables), but mysql allows using JOIN directly in
      # an UPDATE statement, so in the mysql adapters we redefine this to do that.
      def join_to_update(update, select) #:nodoc:
        key = update.key
        subselect = subquery_for(key, select)

        update.where key.in(subselect)
      end

      def join_to_delete(delete, select, key) #:nodoc:
        subselect = subquery_for(key, select)

        delete.where key.in(subselect)
      end

      protected

        # Return a subquery for the given key using the join information.
        def subquery_for(key, select)
          subselect = select.clone
          subselect.projections = [key]
          subselect
        end

        # Returns an array of record hashes with the column names as keys and
        # column values as values.
        def select(sql, name = nil, binds = [])
        end
        undef_method :select

        # Returns the last auto-generated ID from the affected table.
        def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
          execute(sql, name)
          id_value
        end

        # Executes the update statement and returns the number of rows affected.
        def update_sql(sql, name = nil)
          execute(sql, name)
        end

        # Executes the delete statement and returns the number of rows affected.
        def delete_sql(sql, name = nil)
          update_sql(sql, name)
        end

      def sql_for_insert(sql, pk, id_value, sequence_name, binds)
        [sql, binds]
      end

      def last_inserted_id(result)
        row = result.rows.first
        row && row.first
      end
    end
  end
end
