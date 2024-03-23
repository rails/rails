# frozen_string_literal: true

require "cases/helper"
require "models/bird"

class BasePreventAccessTest < ActiveRecord::TestCase
  if !in_memory_db?
    test "selecting a record raises if preventing access" do
      bird = Bird.create! name: "Bluejay"

      ActiveRecord::Base.while_preventing_access do
        assert_raises ActiveRecord::PreventedAccessError do
          assert_equal bird, Bird.where(name: "Bluejay").last
        end
      end
    end

    test "preventing access applies only within while_preventing_access blocks" do
      Bird.create! name: "Bluejay"

      ActiveRecord::Base.while_preventing_access do
        conn1_error = assert_raises ActiveRecord::PreventedAccessError do
          Bird.where(name: "Bluejay").last
        end

        assert_match %r/\AQuery attempted while preventing access: SELECT /, conn1_error.message
      end

      Professor.create!(name: "Professor Bluejay")

      ActiveRecord::Base.while_preventing_access do
        conn2_error = assert_raises ActiveRecord::PreventedAccessError do
          Professor.create!(name: "Professor Magnificent Frigatebird")
        end

        assert_match %r/\AQuery attempted while preventing access: INSERT /, conn2_error.message
      end
    end

    test "preventing_access?" do
      ActiveRecord::Base.while_preventing_access do
        assert_predicate ActiveRecord::Base, :preventing_access?, "expected preventing_access? to return true"
      end
    end
  end
end
