# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

if ActiveRecord::Base.lease_connection.supports_check_constraints?
  class Mysql2CheckConstraintQuotingTest < ActiveRecord::Mysql2TestCase
    include SchemaDumpingHelper

    setup do
      @connection = ActiveRecord::Base.lease_connection
      @connection.create_table "trades", force: true do |t|
        t.string :name
      end
    end

    teardown do
      @connection.drop_table "trades", if_exists: true rescue nil
    end

    def test_check_constraint_no_duplicate_expression_quoting
      @connection.add_check_constraint :trades, "name != 'forbidden_string'"

      check_constraints = @connection.check_constraints("trades")
      assert_equal 1, check_constraints.size

      expression = check_constraints.first.expression
      if ActiveRecord::Base.lease_connection.mariadb?
        assert_equal "`name` <> 'forbidden_string'", expression
      else
        assert_equal "`name` <> _utf8mb4'forbidden_string'", expression
      end
    end
  end
end
