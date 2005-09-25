module ActiveRecord
  module ConnectionAdapters # :nodoc:
    # TODO: Document me!
    module DatabaseStatements
      # Returns an array of record hashes with the column names as a keys and fields as values.
      def select_all(sql, name = nil) end

      # Returns a record hash with the column names as a keys and fields as values.
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

      # Executes the statement
      def execute(sql, name = nil) end

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

      # Rolls back the transaction (and turns on auto-committing). Must be done if the transaction block
      # raises an exception or returns false.
      def rollback_db_transaction() end

      def add_limit!(sql, options) #:nodoc:
        return unless options
        add_limit_offset!(sql, options)
      end

      def add_limit_offset!(sql, options) #:nodoc:
        return if options[:limit].nil?
        sql << " LIMIT #{options[:limit]}"
        sql << " OFFSET #{options[:offset]}" if options.has_key?(:offset) and !options[:offset].nil?
      end
    end
  end
end