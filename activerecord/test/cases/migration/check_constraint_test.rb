# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

if ActiveRecord::Base.connection.supports_check_constraints?
  module ActiveRecord
    class Migration
      class CheckConstraintTest < ActiveRecord::TestCase
        include SchemaDumpingHelper

        class Trade < ActiveRecord::Base
        end

        setup do
          @connection = ActiveRecord::Base.connection
          @connection.create_table "trades", force: true do |t|
            t.integer :price
            t.integer :quantity
          end
        end

        teardown do
          @connection.drop_table "trades", if_exists: true
        end

        def test_check_constraints
          check_constraints = @connection.check_constraints("products")
          assert_equal 1, check_constraints.size

          constraint = check_constraints.first
          assert_equal "products", constraint.table_name
          assert_equal "products_price_check", constraint.name

          if current_adapter?(:Mysql2Adapter)
            assert_equal "`price` > `discounted_price`", constraint.expression
          else
            assert_equal "price > discounted_price", constraint.expression
          end
        end

        def test_add_check_constraint
          @connection.add_check_constraint :trades, "quantity > 0"

          check_constraints = @connection.check_constraints("trades")
          assert_equal 1, check_constraints.size

          constraint = check_constraints.first
          assert_equal "trades", constraint.table_name
          assert_equal "chk_rails_2189e9f96c", constraint.name

          if current_adapter?(:Mysql2Adapter)
            assert_equal "`quantity` > 0", constraint.expression
          else
            assert_equal "quantity > 0", constraint.expression
          end
        end

        def test_added_check_constraint_ensures_valid_values
          @connection.add_check_constraint :trades, "quantity > 0", name: "quantity_check"

          assert_raises(ActiveRecord::StatementInvalid) do
            Trade.create(quantity: -1)
          end
        end

        if ActiveRecord::Base.connection.supports_validate_constraints?
          def test_not_valid_check_constraint
            Trade.create(quantity: -1)

            @connection.add_check_constraint :trades, "quantity > 0", name: "quantity_check", validate: false

            assert_raises(ActiveRecord::StatementInvalid) do
              Trade.create(quantity: -1)
            end
          end

          def test_validate_check_constraint_by_name
            @connection.add_check_constraint :trades, "quantity > 0", name: "quantity_check", validate: false
            assert_not_predicate @connection.check_constraints("trades").first, :validated?

            @connection.validate_check_constraint :trades, name: "quantity_check"
            assert_predicate @connection.check_constraints("trades").first, :validated?
          end

          def test_validate_non_existing_check_constraint_raises
            assert_raises ArgumentError do
              @connection.validate_check_constraint :trades, name: "quantity_check"
            end
          end
        else
          # Check constraint should still be created, but should not be invalid
          def test_add_invalid_check_constraint
            @connection.add_check_constraint :trades, "quantity > 0", name: "quantity_check", validate: false

            check_constraints = @connection.check_constraints("trades")
            assert_equal 1, check_constraints.size

            cc = check_constraints.first
            assert_predicate cc, :validated?
          end
        end

        def test_remove_check_constraint
          @connection.add_check_constraint :trades, "price > 0", name: "price_check"
          @connection.add_check_constraint :trades, "quantity > 0", name: "quantity_check"

          assert_equal 2, @connection.check_constraints("trades").size
          @connection.remove_check_constraint :trades, name: "quantity_check"
          assert_equal 1, @connection.check_constraints("trades").size

          constraint = @connection.check_constraints("trades").first
          assert_equal "trades", constraint.table_name
          assert_equal "price_check", constraint.name

          if current_adapter?(:Mysql2Adapter)
            assert_equal "`price` > 0", constraint.expression
          else
            assert_equal "price > 0", constraint.expression
          end
        end

        def test_remove_non_existing_check_constraint
          assert_raises(ArgumentError) do
            @connection.remove_check_constraint :trades, name: "nonexistent"
          end
        end
      end
    end
  end
else
  module ActiveRecord
    class Migration
      class NoForeignKeySupportTest < ActiveRecord::TestCase
        setup do
          @connection = ActiveRecord::Base.connection
        end

        def test_add_check_constraint_should_be_noop
          @connection.add_check_constraint :products, "discounted_price > 0", name: "discounted_price_check"
        end

        def test_remove_check_constraint_should_be_noop
          @connection.remove_check_constraint :products, name: "price_check"
        end

        def test_check_constraints_should_raise_not_implemented
          assert_raises(NotImplementedError) do
            @connection.check_constraints("products")
          end
        end
      end
    end
  end
end
