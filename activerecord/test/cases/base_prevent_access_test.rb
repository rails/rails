# frozen_string_literal: true

require "cases/helper"
require "models/bird"

class BasePreventWritesTest < ActiveRecord::TestCase
  if !in_memory_db?
    test "selecting a record raises if preventing access" do
      bird = Bird.create! name: "Bluejay"

      ActiveRecord::Base.while_preventing_access do
        assert_raises ActiveRecord::PreventedAccessError do
          assert_equal bird, Bird.where(name: "Bluejay").last
        end
      end
    end

    test "preventing access applies to all connections in block" do
      Bird.create! name: "Bluejay"

      ActiveRecord::Base.while_preventing_access do
        conn1_error = assert_raises ActiveRecord::PreventedAccessError do
          assert_equal ActiveRecord::Base.lease_connection, Bird.lease_connection
          assert_not_equal ARUnit2Model.lease_connection, Bird.lease_connection
          Bird.where(name: "Bluejay").last
        end

        assert_match %r/\AQuery attempted while preventing access: SELECT /, conn1_error.message
      end

      Professor.create!(name: "Professor Bluejay")

      ActiveRecord::Base.while_preventing_access do
        conn2_error = assert_raises ActiveRecord::PreventedAccessError do
          assert_not_equal ActiveRecord::Base.lease_connection, Professor.lease_connection
          assert_equal ARUnit2Model.lease_connection, Professor.lease_connection
          Professor.create!(name: "Professor Magnificent Frigatebird")
        end

        assert_match %r/\AQuery attempted while preventing access: INSERT /, conn2_error.message
      end
    end

    test "current_preventing_access" do
      ActiveRecord::Base.while_preventing_access do
        assert ActiveRecord::Base.current_preventing_access, "expected connection current_preventing_access to return true"
      end
    end
  end
end
