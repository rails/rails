# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

module ActiveRecord
  class Mysql2NestedDeadlockTest < ActiveRecord::Mysql2TestCase
    self.use_transactional_tests = false

    class Sample < ActiveRecord::Base
      self.table_name = "samples"
    end

    setup do
      @abort, Thread.abort_on_exception = Thread.abort_on_exception, false
      Thread.report_on_exception, @original_report_on_exception = false, Thread.report_on_exception

      connection = ActiveRecord::Base.connection
      connection.clear_cache!

      connection.create_table("samples", force: true) do |t|
        t.integer "value"
      end

      Sample.reset_column_information
    end

    teardown do
      ActiveRecord::Base.clear_active_connections!
      ActiveRecord::Base.connection.drop_table "samples", if_exists: true

      Thread.abort_on_exception = @abort
      Thread.report_on_exception = @original_report_on_exception
    end

    test "deadlock correctly raises Deadlocked inside nested SavepointTransaction" do
      assert_raises(ActiveRecord::Deadlocked) do
        barrier = Concurrent::CyclicBarrier.new(2)

        s1 = Sample.create value: 1
        s2 = Sample.create value: 2

        begin
          thread = Thread.new do
            Sample.transaction(requires_new: false) do
              Sample.transaction(requires_new: true) do
                s1.lock!
                barrier.wait
                s2.update value: 1
              end
            end
          end

          begin
            Sample.transaction(requires_new: false) do
              Sample.transaction(requires_new: true) do
                s2.lock!
                barrier.wait
                s1.update value: 2
              end
            end
          ensure
            thread.join
          end
        rescue ActiveRecord::StatementInvalid => e
          if /SAVEPOINT active_record_. does not exist/ =~ e.to_s
            flunk "ROLLBACK TO SAVEPOINT query issued for savepoint that no longer exists due to deadlock: #{e}"
          else
            raise e
          end
        end
      end
    end
  end
end
