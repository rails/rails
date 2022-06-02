# frozen_string_literal: true

require "cases/helper"
require "models/course"
require "models/entrant"

module ActiveRecord
  class PreparedStatementStatusTest < ActiveRecord::TestCase
    def test_prepared_statement_status_is_thread_and_instance_specific
      course_conn = Course.connection
      entrant_conn = Entrant.connection

      inside = Concurrent::Event.new
      preventing = Concurrent::Event.new
      finished = Concurrent::Event.new

      assert_not_same course_conn, entrant_conn

      if ActiveRecord::Base.connection.prepared_statements
        t1 = Thread.new do
          course_conn.unprepared_statement do
            inside.set
            preventing.wait
            assert_not course_conn.prepared_statements
            assert entrant_conn.prepared_statements
            finished.set
          end
        end

        t2 = Thread.new do
          entrant_conn.unprepared_statement do
            inside.wait
            assert course_conn.prepared_statements
            assert_not entrant_conn.prepared_statements
            preventing.set
            finished.wait
          end
        end

        t1.join
        t2.join
      else
        assert_not course_conn.prepared_statements
        assert_not entrant_conn.prepared_statements
      end
    end
  end
end
