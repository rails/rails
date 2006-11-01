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
        result = select(sql, name)
        result.first if result
      end

      # Returns a single value from a record
      def select_value(sql, name = nil)
        result = select_one(sql, name)
        result.nil? ? nil : result.values.first
      end

      # Returns an array of the values of the first column in a select:
      #   select_values("SELECT id FROM companies LIMIT 3") => [1,2,3]
      def select_values(sql, name = nil)
        result = select_all(sql, name)
        result.map{ |v| v.values.first }
      end

      # Executes the SQL statement in the context of this connection.
      def execute(sql, name = nil)
        raise NotImplementedError, "execute is an abstract method"
      end

      # Returns the last auto-generated ID from the affected table.
      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        raise NotImplementedError, "insert is an abstract method"
      end

      # Executes the update statement and returns the number of rows affected.
      def update(sql, name = nil)
        execute(sql, name)
      end

      # Executes the delete statement and returns the number of rows affected.
      def delete(sql, name = nil)
        update(sql, name)
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
          raise
        end
      ensure
        commit_db_transaction if transaction_open
      end

      # Begins the transaction (and turns off auto-committing).
      def begin_db_transaction()    end

      # Commits the transaction (and turns on auto-committing).
      def commit_db_transaction()   end

      # Rolls back the transaction (and turns on auto-committing). Must be
      # done if the transaction block raises an exception or returns false.
      def rollback_db_transaction() end

      # Alias for #add_limit_offset!.
      def add_limit!(sql, options)
        add_limit_offset!(sql, options) if options
      end

      # Appends +LIMIT+ and +OFFSET+ options to a SQL statement.
      # This method *modifies* the +sql+ parameter.
      # ===== Examples
      #  add_limit_offset!('SELECT * FROM suppliers', {:limit => 10, :offset => 50})
      # generates
      #  SELECT * FROM suppliers LIMIT 10 OFFSET 50
      def add_limit_offset!(sql, options)
        if limit = options[:limit]
          sql << " LIMIT #{limit}"
          if offset = options[:offset]
            sql << " OFFSET #{offset}"
          end
        end
      end

      # Appends a locking clause to a SQL statement. *Modifies the +sql+ parameter*.
      #   # SELECT * FROM suppliers FOR UPDATE
      #   add_lock! 'SELECT * FROM suppliers', :lock => true
      #   add_lock! 'SELECT * FROM suppliers', :lock => ' FOR UPDATE'
      def add_lock!(sql, options)
        case lock = options[:lock]
          when true:   sql << ' FOR UPDATE'
          when String: sql << " #{lock}"
        end
      end

      def default_sequence_name(table, column)
        nil
      end

      # Set the sequence to the max value of the table's column.
      def reset_sequence!(table, column, sequence = nil)
        # Do nothing by default.  Implement for PostgreSQL, Oracle, ...
      end

      protected
        # Returns an array of record hashes with the column names as keys and
        # column values as values.
        def select(sql, name = nil)
          raise NotImplementedError, "select is an abstract method"
        end
    end
  end
end
