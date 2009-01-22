module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module DatabaseStatements
      # Returns an array of record hashes with the column names as keys and
      # column values as values.
      def select_all(sql, name = nil)
        select(sql, name)
      end

      # Returns a record hash with the column names as keys and column values
      # as values.
      def select_one(sql, name = nil)
        result = select_all(sql, name)
        result.first if result
      end

      # Returns a single value from a record
      def select_value(sql, name = nil)
        if result = select_one(sql, name)
          result.values.first
        end
      end

      # Returns an array of the values of the first column in a select:
      #   select_values("SELECT id FROM companies LIMIT 3") => [1,2,3]
      def select_values(sql, name = nil)
        result = select_rows(sql, name)
        result.map { |v| v[0] }
      end

      # Returns an array of arrays containing the field values.
      # Order is the same as that returned by +columns+.
      def select_rows(sql, name = nil)
      end
      undef_method :select_rows

      # Executes the SQL statement in the context of this connection.
      def execute(sql, name = nil, skip_logging = false)
      end
      undef_method :execute

      # Returns the last auto-generated ID from the affected table.
      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        insert_sql(sql, name, pk, id_value, sequence_name)
      end

      # Executes the update statement and returns the number of rows affected.
      def update(sql, name = nil)
        update_sql(sql, name)
      end

      # Executes the delete statement and returns the number of rows affected.
      def delete(sql, name = nil)
        delete_sql(sql, name)
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
      # http://dev.mysql.com/doc/refman/5.0/en/savepoints.html
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

        last_transaction_joinable = @transaction_joinable
        if options.has_key?(:joinable)
          @transaction_joinable = options[:joinable]
        else
          @transaction_joinable = true
        end
        requires_new = options[:requires_new] || !last_transaction_joinable

        transaction_open = false
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
            end
            yield
          end
        rescue Exception => database_transaction_rollback
          if transaction_open && !outside_transaction?
            transaction_open = false
            decrement_open_transactions
            if open_transactions == 0
              rollback_db_transaction
            else
              rollback_to_savepoint
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
            else
              release_savepoint
            end
          rescue Exception => database_transaction_rollback
            if open_transactions == 0
              rollback_db_transaction
            else
              rollback_to_savepoint
            end
            raise
          end
        end
      end
      
      # Begins the transaction (and turns off auto-committing).
      def begin_db_transaction()    end

      # Commits the transaction (and turns on auto-committing).
      def commit_db_transaction()   end

      # Rolls back the transaction (and turns on auto-committing). Must be
      # done if the transaction block raises an exception or returns false.
      def rollback_db_transaction() end

      # Alias for <tt>add_limit_offset!</tt>.
      def add_limit!(sql, options)
        add_limit_offset!(sql, options) if options
      end

      # Appends +LIMIT+ and +OFFSET+ options to an SQL statement, or some SQL
      # fragment that has the same semantics as LIMIT and OFFSET.
      #
      # +options+ must be a Hash which contains a +:limit+ option (required)
      # and an +:offset+ option (optional).
      #
      # This method *modifies* the +sql+ parameter.
      #
      # ===== Examples
      #  add_limit_offset!('SELECT * FROM suppliers', {:limit => 10, :offset => 50})
      # generates
      #  SELECT * FROM suppliers LIMIT 10 OFFSET 50
      def add_limit_offset!(sql, options)
        if limit = options[:limit]
          sql << " LIMIT #{sanitize_limit(limit)}"
          if offset = options[:offset]
            sql << " OFFSET #{offset.to_i}"
          end
        end
        sql
      end

      # Appends a locking clause to an SQL statement.
      # This method *modifies* the +sql+ parameter.
      #   # SELECT * FROM suppliers FOR UPDATE
      #   add_lock! 'SELECT * FROM suppliers', :lock => true
      #   add_lock! 'SELECT * FROM suppliers', :lock => ' FOR UPDATE'
      def add_lock!(sql, options)
        case lock = options[:lock]
          when true;   sql << ' FOR UPDATE'
          when String; sql << " #{lock}"
        end
      end

      def default_sequence_name(table, column)
        nil
      end

      # Set the sequence to the max value of the table's column.
      def reset_sequence!(table, column, sequence = nil)
        # Do nothing by default.  Implement for PostgreSQL, Oracle, ...
      end

      # Inserts the given fixture into the table. Overridden in adapters that require
      # something beyond a simple insert (eg. Oracle).
      def insert_fixture(fixture, table_name)
        execute "INSERT INTO #{quote_table_name(table_name)} (#{fixture.key_list}) VALUES (#{fixture.value_list})", 'Fixture Insert'
      end

      def empty_insert_statement(table_name)
        "INSERT INTO #{quote_table_name(table_name)} VALUES(DEFAULT)"
      end

      def case_sensitive_equality_operator
        "="
      end

      def limited_update_conditions(where_sql, quoted_table_name, quoted_primary_key)
        "WHERE #{quoted_primary_key} IN (SELECT #{quoted_primary_key} FROM #{quoted_table_name} #{where_sql})"
      end

      protected
        # Returns an array of record hashes with the column names as keys and
        # column values as values.
        def select(sql, name = nil)
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

        # Sanitizes the given LIMIT parameter in order to prevent SQL injection.
        #
        # +limit+ may be anything that can evaluate to a string via #to_s. It
        # should look like an integer, or a comma-delimited list of integers.
        #
        # Returns the sanitized limit parameter, either as an integer, or as a
        # string which contains a comma-delimited list of integers.
        def sanitize_limit(limit)
          if limit.to_s =~ /,/
            limit.to_s.split(',').map{ |i| i.to_i }.join(',')
          else
            limit.to_i
          end
        end
    end
  end
end
