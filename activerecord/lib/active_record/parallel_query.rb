# frozen_string_literal: true

module ActiveRecord
  # This module provides support for executing parallel queries in PostgreSQL
  # by dynamically adjusting the database settings to leverage multiple CPU cores.
  module ParallelQuery
    extend ActiveSupport::Concern

    included do
      def self.parallel_query(max_workers: 4, &block)
        adapter_name = connection.adapter_name.downcase

        if adapter_name == "postgresql"
          execute_with_parallel_postgresql(max_workers, &block)
        else # Currently other adapters have no such functionality, yieldng the givan block directly aprat from postgres, (Future we can include if other adapters has such functlity)
          yield
        end
      end

      private
        def self.execute_with_parallel_postgresql(max_workers)
          begin
            set_postgresql_parallel_settings(max_workers)
            yield
          ensure
            reset_postgresql_parallel_settings
          end
        end

        # Sets PostgreSQL settings to enable and optimize parallel query execution.
        # @param max_workers [Integer] The maximum number of parallel workers to use.

        def self.set_postgresql_parallel_settings(max_workers)
          connection.execute("SET max_parallel_workers_per_gather = #{max_workers}")
          connection.execute("SET work_mem = '64MB'")
          connection.execute("SET parallel_setup_cost = 100")
          connection.execute("SET parallel_tuple_cost = 0.01")
          connection.execute("SET min_parallel_table_scan_size = 0")
          connection.execute("SET min_parallel_index_scan_size = 0")
        end

        # Resets PostgreSQL settings to their default values.
        def self.reset_postgresql_parallel_settings
          connection.execute("RESET max_parallel_workers_per_gather")
          connection.execute("RESET work_mem")
          connection.execute("RESET parallel_setup_cost")
          connection.execute("RESET parallel_tuple_cost")
          connection.execute("RESET min_parallel_table_scan_size")
          connection.execute("RESET min_parallel_index_scan_size")
        end
    end
  end
end


# Please find the explanation of each setting with comments about the chosen values:

# max_parallel_workers_per_gather
# Sets the maximum number of workers that can be used for a parallel query.
# max_workers is dynamically set to allow flexibility.

# work_mem
# Allocates 64MB of memory for operations to minimize disk I/O, making queries faster.
# The value 64MB is a balanced choice to improve performance without overloading the system.

# parallel_setup_cost
# Lowers the setup cost for parallel execution, making it more likely to be used by the planner.
# Default value is 1000; setting it to 100 encourages the planner to choose parallel execution.

# parallel_tuple_cost
# Reduces the cost of processing each tuple (row) in a parallel query plan.
# Default value is 0.1; setting it to 0.01 further encourages parallel execution.

# min_parallel_table_scan_size
# Ensures that even small table scans are considered for parallel execution.
# Setting to 0 makes all table scans eligible for parallel execution.

# min_parallel_index_scan_size
# Ensures that even small index scans are considered for parallel execution.
# Setting to 0 makes all index scans eligible for parallel execution.
