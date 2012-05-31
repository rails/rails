module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module DatabaseStatements
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
      # +binds+ as the bind substitutes. +name+ is the logged along with
      # the executed +sql+ statement.
      def exec_insert(sql, name, binds)
        exec_query(sql, name, binds)
      end

      # Executes delete +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is the logged along with
      # the executed +sql+ statement.
      def exec_delete(sql, name, binds)
        exec_query(sql, name, binds)
      end

      # Executes update +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is the logged along with
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
        value      = exec_insert(sql, name, binds)
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

      # Checks whether there is currently no transaction active. This is done
      # by querying the database driver, and does not use the transaction
      # house-keeping information recorded by #increment_open_transactions and
      # friends.
      #
      # Returns true if there is no transaction active, false if there is a
      # transaction active, and nil if this information is unknown.
      #
      # Not all adapters supports transaction state introspection. Currently,
      # only the PostgreSQL adapter supports this.
      def outside_transaction?
        nil
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
      #     Model.connection.transaction(:requires_new => true) do  # CREATE SAVEPOINT active_record_1
      #       Model.connection.create_table(...)
      #       # active_record_1 now automatically released
      #     end  # RELEASE SAVEPOINT active_record_1  <--- BOOM! database error!
      #   end
      def transaction(options = {})
        options.assert_valid_keys :requires_new, :joinable

        last_transaction_joinable = defined?(@transaction_joinable) ? @transaction_joinable : nil
        if options.has_key?(:joinable)
          @transaction_joinable = options[:joinable]
        else
          @transaction_joinable = true
        end
        requires_new = options[:requires_new] || !last_transaction_joinable

        transaction_open = false
        @_current_transaction_records ||= []

        begin
          if block_given?
            if requires_new || open_transactions == 0
              if open_transactions == 0
                begin_db_transaction
              elsif requires_new
                create_savepoint
              end
              increment_open_transactions
              transaction_open = true
              @_current_transaction_records.push([])
            end
            yield
          end
        rescue Exception => database_transaction_rollback
          if transaction_open && !outside_transaction?
            transaction_open = false
            decrement_open_transactions
            if open_transactions == 0
              rollback_db_transaction
              rollback_transaction_records(true)
            else
              rollback_to_savepoint
              rollback_transaction_records(false)
            end
          end
          raise unless database_transaction_rollback.is_a?(ActiveRecord::Rollback)
        end
      ensure
        @transaction_joinable = last_transaction_joinable

        if outside_transaction?
          @open_transactions = 0
        elsif transaction_open
          decrement_open_transactions
          begin
            if open_transactions == 0
              commit_db_transaction
              commit_transaction_records
            else
              release_savepoint
              save_point_records = @_current_transaction_records.pop
              unless save_point_records.blank?
                @_current_transaction_records.push([]) if @_current_transaction_records.empty?
                @_current_transaction_records.last.concat(save_point_records)
              end
            end
          rescue Exception => database_transaction_rollback
            if open_transactions == 0
              rollback_db_transaction
              rollback_transaction_records(true)
            else
              rollback_to_savepoint
              rollback_transaction_records(false)
            end
            raise
          end
        end
      end

      # Register a record with the current transaction so that its after_commit and after_rollback callbacks
      # can be called.
      def add_transaction_record(record)
        last_batch = @_current_transaction_records.last
        last_batch << record if last_batch
      end

      # Begins the transaction (and turns off auto-committing).
      def begin_db_transaction()    end

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
        "VALUES(DEFAULT)"
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
        subselect = select.clone
        subselect.projections = [update.key]

        update.where update.key.in(subselect)
      end

      protected
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

        # Send a rollback message to all records after they have been rolled back. If rollback
        # is false, only rollback records since the last save point.
        def rollback_transaction_records(rollback)
          if rollback
            records = @_current_transaction_records.flatten
            @_current_transaction_records.clear
          else
            records = @_current_transaction_records.pop
          end

          unless records.blank?
            records.uniq.each do |record|
              begin
                record.rolledback!(rollback)
              rescue Exception => e
                record.logger.error(e) if record.respond_to?(:logger) && record.logger
              end
            end
          end
        end

        # Send a commit message to all records after they have been committed.
        def commit_transaction_records
          records = @_current_transaction_records.flatten
          @_current_transaction_records.clear
          unless records.blank?
            records.uniq.each do |record|
              begin
                record.committed!
              rescue Exception => e
                record.logger.error(e) if record.respond_to?(:logger) && record.logger
              end
            end
          end
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
