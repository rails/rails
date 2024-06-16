require "cases/helper"
require "active_record"
require "models/element"

class ParallelQueryTest < ActiveRecord::TestCase
  self.use_transactional_tests = true

  fixtures :elements

  setup do
    @postgresql = ActiveRecord::Base.connection.adapter_name.downcase == "postgresql"
  end

  def test_parallel_execution_plan
    unless @postgresql
      skip "EXPLAIN ANALYZE with parallel execution is supported only in PostgreSQL"
    end

    explain_output = Element.parallel_query(max_workers: 4) do
      # Note the Postgres will set the Max workers only when if the query or the block supposed to be executed with max workers -> on basis of complexity.

      ActiveRecord::Base.connection.execute("
        EXPLAIN ANALYZE
        SELECT
          parent.name AS parent_name,
          COUNT(child.id) AS child_count,
          AVG(child.id) AS avg_child_id,
          MAX(child.id) AS max_child_id,
          MIN(child.id) AS min_child_id,
          SUM(child.id) AS sum_child_id,
          COUNT(DISTINCT child.name) AS distinct_child_names,
          COUNT(DISTINCT parent.name) AS distinct_parent_names
        FROM elements AS parent
        LEFT JOIN elements AS child ON parent.id = child.parent_id
        WHERE child.created_at >= '2020-01-01' AND parent.created_at >= '2020-01-01'
        GROUP BY parent.name
        HAVING COUNT(child.id) > 100
        ORDER BY child_count DESC, parent.name ASC
      ")
    end

    explain_output.each do |line|
      puts line["QUERY PLAN"] # To see the output in test logs
      if line["QUERY PLAN"].include?("Gather") || line["QUERY PLAN"].include?("Parallel")
        assert true
        return
      end
    end

    assert false, "Expected 'Gather' or 'Parallel' in the EXPLAIN ANALYZE output, but it was not found"
  end

  def test_settings_reset
    unless @postgresql
      skip "SHOW command is supported only in PostgreSQL"
    end

    initial_settings = {
      max_parallel_workers_per_gather: ActiveRecord::Base.connection.execute("SHOW max_parallel_workers_per_gather").first["max_parallel_workers_per_gather"],
      work_mem: ActiveRecord::Base.connection.execute("SHOW work_mem").first["work_mem"],
      parallel_setup_cost: ActiveRecord::Base.connection.execute("SHOW parallel_setup_cost").first["parallel_setup_cost"],
      parallel_tuple_cost: ActiveRecord::Base.connection.execute("SHOW parallel_tuple_cost").first["parallel_tuple_cost"],
      min_parallel_table_scan_size: ActiveRecord::Base.connection.execute("SHOW min_parallel_table_scan_size").first["min_parallel_table_scan_size"],
      min_parallel_index_scan_size: ActiveRecord::Base.connection.execute("SHOW min_parallel_index_scan_size").first["min_parallel_index_scan_size"]
    }

    Element.parallel_query(max_workers: 4) do
      Element.joins("LEFT JOIN elements AS child ON elements.id = child.parent_id")
             .group("elements.name")
             .select("elements.name AS parent_name, COUNT(child.id) AS child_count, AVG(child.id) AS avg_child_id, MAX(child.id) AS max_child_id, MIN(child.id) AS min_child_id, SUM(child.id) AS sum_child_id")
             .order("child_count DESC")
    end

    reset_settings = {
      max_parallel_workers_per_gather: ActiveRecord::Base.connection.execute("SHOW max_parallel_workers_per_gather").first["max_parallel_workers_per_gather"],
      work_mem: ActiveRecord::Base.connection.execute("SHOW work_mem").first["work_mem"],
      parallel_setup_cost: ActiveRecord::Base.connection.execute("SHOW parallel_setup_cost").first["parallel_setup_cost"],
      parallel_tuple_cost: ActiveRecord::Base.connection.execute("SHOW parallel_tuple_cost").first["parallel_tuple_cost"],
      min_parallel_table_scan_size: ActiveRecord::Base.connection.execute("SHOW min_parallel_table_scan_size").first["min_parallel_table_scan_size"],
      min_parallel_index_scan_size: ActiveRecord::Base.connection.execute("SHOW min_parallel_index_scan_size").first["min_parallel_index_scan_size"]
    }

    assert_equal initial_settings, reset_settings
  end

  def test_query_execution_on_other_adapters
    if @postgresql
      skip "This test is for other adapters"
    end

    assert_nothing_raised do
      Element.parallel_query(max_workers: 4) do
        Element.joins("LEFT JOIN elements AS child ON elements.id = child.parent_id")
        .group("elements.name")
        .select("elements.name AS parent_name, COUNT(child.id) AS child_count, AVG(child.id) AS avg_child_id, MAX(child.id) AS max_child_id, MIN(child.id) AS min_child_id, SUM(child.id) AS sum_child_id")
        .order("child_count DESC")
      end
    end

    result =  Element.parallel_query(max_workers: 4) do
      Element.joins("LEFT JOIN elements AS child ON elements.id = child.parent_id")
      .group("elements.name")
      .select("elements.name AS parent_name, COUNT(child.id) AS child_count, AVG(child.id) AS avg_child_id, MAX(child.id) AS max_child_id, MIN(child.id) AS min_child_id, SUM(child.id) AS sum_child_id")
      .order("child_count DESC")
    end

    assert result.any?, "Expected query to return results"
  end

  def test_query_execution_time_comparison
    unless @postgresql
      skip "Execution time comparison is supported only in PostgreSQL"
    end

    baseline_time = Benchmark.realtime do
      Element.joins("LEFT JOIN elements AS child ON elements.id = child.parent_id")
      .group('elements.name')
      .select('elements.name AS parent_name, COUNT(child.id) AS child_count, AVG(child.id) AS avg_child_id, MAX(child.id) AS max_child_id, MIN(child.id) AS min_child_id, SUM(child.id) AS sum_child_id, COUNT(DISTINCT child.name) AS distinct_child_names, COUNT(DISTINCT elements.name) AS distinct_parent_names')
      .where("child.created_at >= '2020-01-01' AND elements.created_at >= '2020-01-01'")
      .having('COUNT(child.id) > 100')
      .order('child_count DESC, elements.name ASC')
      .to_a
    end

    parallel_time = Benchmark.realtime do
      Element.parallel_query(max_workers: 4) do
        Element.joins("LEFT JOIN elements AS child ON elements.id = child.parent_id")
        .group('elements.name')
        .select('elements.name AS parent_name, COUNT(child.id) AS child_count, AVG(child.id) AS avg_child_id, MAX(child.id) AS max_child_id, MIN(child.id) AS min_child_id, SUM(child.id) AS sum_child_id, COUNT(DISTINCT child.name) AS distinct_child_names, COUNT(DISTINCT elements.name) AS distinct_parent_names')
        .where("child.created_at >= '2020-01-01' AND elements.created_at >= '2020-01-01'")
        .having('COUNT(child.id) > 100')
        .order('child_count DESC, elements.name ASC')
        .to_a
      end
    end

    puts "Baseline execution time: #{baseline_time} seconds"
    puts "Parallel execution time: #{parallel_time} seconds"

    assert_operator parallel_time, :<, baseline_time, "Expected parallel execution to be faster than baseline execution"
  end
end