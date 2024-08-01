# frozen_string_literal: true

require "cases/helper"
require "models/bird"

class BasePreventWritesTest < ActiveRecord::TestCase
  if !in_memory_db?
    test "creating a record raises if preventing writes" do
      ActiveRecord::Base.while_preventing_writes do
        error = assert_raises ActiveRecord::ReadOnlyError do
          Bird.create! name: "Bluejay"
        end

        assert_match %r/\AWrite query attempted while in readonly mode: INSERT /, error.message
      end
    end

    test "updating a record raises if preventing writes" do
      bird = Bird.create! name: "Bluejay"

      ActiveRecord::Base.while_preventing_writes do
        error = assert_raises ActiveRecord::ReadOnlyError do
          bird.update! name: "Robin"
        end

        assert_match %r/\AWrite query attempted while in readonly mode: UPDATE /, error.message
      end
    end

    test "deleting a record raises if preventing writes" do
      bird = Bird.create! name: "Bluejay"

      ActiveRecord::Base.while_preventing_writes do
        error = assert_raises ActiveRecord::ReadOnlyError do
          bird.destroy!
        end

        assert_match %r/\AWrite query attempted while in readonly mode: DELETE /, error.message
      end
    end

    test "selecting a record does not raise if preventing writes" do
      bird = Bird.create! name: "Bluejay"

      ActiveRecord::Base.while_preventing_writes do
        assert_equal bird, Bird.where(name: "Bluejay").last
      end
    end

    test "an explain query does not raise if preventing writes" do
      Bird.create!(name: "Bluejay")

      ActiveRecord::Base.while_preventing_writes do
        assert_queries_count(2) { Bird.where(name: "Bluejay").explain.inspect }
      end
    end

    test "an empty transaction does not raise if preventing writes" do
      ActiveRecord::Base.while_preventing_writes do
        assert_queries_count(2, include_schema: true) do
          Bird.transaction do
            ActiveRecord::Base.lease_connection.materialize_transactions
          end
        end
      end
    end

    test "preventing writes applies to all connections in block" do
      ActiveRecord::Base.while_preventing_writes do
        conn1_error = assert_raises ActiveRecord::ReadOnlyError do
          assert_equal ActiveRecord::Base.lease_connection, Bird.lease_connection
          assert_not_equal ARUnit2Model.lease_connection, Bird.lease_connection
          Bird.create!(name: "Bluejay")
        end

        assert_match %r/\AWrite query attempted while in readonly mode: INSERT /, conn1_error.message
      end

      ActiveRecord::Base.while_preventing_writes do
        conn2_error = assert_raises ActiveRecord::ReadOnlyError do
          assert_not_equal ActiveRecord::Base.lease_connection, Professor.lease_connection
          assert_equal ARUnit2Model.lease_connection, Professor.lease_connection
          Professor.create!(name: "Professor Bluejay")
        end

        assert_match %r/\AWrite query attempted while in readonly mode: INSERT /, conn2_error.message
      end
    end

    test "current_preventing_writes" do
      ActiveRecord::Base.while_preventing_writes do
        assert ActiveRecord::Base.current_preventing_writes, "expected connection current_preventing_writes to return true"
      end
    end
  end
end
