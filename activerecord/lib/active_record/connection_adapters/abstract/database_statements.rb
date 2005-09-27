module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module DatabaseStatements
      # Returns an array of record hashes with the column names as keys and
      # column values as values.
      def select_all(sql, name = nil) end

      # Returns a record hash with the column names as keys and column values
      # as values.
      def select_one(sql, name = nil) end

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
      # This abstract method raises a NotImplementedError.
      def execute(sql, name = nil)
        raise NotImplementedError, "execute is an abstract method"
      end

      # Returns the last auto-generated ID from the affected table.
      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) end

      # Executes the update statement and returns the number of rows affected.
      def update(sql, name = nil) end

      # Executes the delete statement and returns the number of rows affected.
      def delete(sql, name = nil) end

      # Wrap a block in a transaction.  Returns result of block.
      def transaction(start_db_transaction = true)
        begin
          if block_given?
            begin_db_transaction if start_db_transaction
            result = yield
            commit_db_transaction if start_db_transaction
            result
          end
        rescue Exception => database_transaction_rollback
          rollback_db_transaction if start_db_transaction
          raise
        end
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
        return unless options
        add_limit_offset!(sql, options)
      end

      # Appends +LIMIT+ and +OFFSET+ options to a SQL statement.
      # This method *modifies* the +sql+ parameter.
      # ===== Examples
      #  add_limit_offset!('SELECT * FROM suppliers', {:limit => 10, :offset => 50})
      # generates
      #  SELECT * FROM suppliers LIMIT 10 OFFSET 50
      def add_limit_offset!(sql, options)
        return if options[:limit].nil?
        sql << " LIMIT #{options[:limit]}"
        sql << " OFFSET #{options[:offset]}" if options.has_key?(:offset) and !options[:offset].nil?
      end
    end
  end
end