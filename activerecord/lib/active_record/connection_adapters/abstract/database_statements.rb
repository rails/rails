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
        raise NotImplementedError, "select_rows is an abstract method"
      end

      # Executes the SQL statement in the context of this connection.
      def execute(sql, name = nil)
        raise NotImplementedError, "execute is an abstract method"
      end

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

      # Wrap a block in a transaction.  Returns result of block.
      def transaction(start_db_transaction = true)
        transaction_open = false
        begin
          if block_given?
            if start_db_transaction
              begin_db_transaction
              transaction_open = true
            end
            yield
          end
        rescue Exception => database_transaction_rollback
          if transaction_open
            transaction_open = false
            rollback_db_transaction
          end
          raise unless database_transaction_rollback.is_a? ActiveRecord::Rollback
        end
      ensure
        if transaction_open
          begin
            commit_db_transaction
          rescue Exception => database_transaction_rollback
            rollback_db_transaction
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
          raise NotImplementedError, "select is an abstract method"
        end

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
