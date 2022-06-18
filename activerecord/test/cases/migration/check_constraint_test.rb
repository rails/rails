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

          @connection.create_table "purchases", force: true do |t|
            t.integer :price
            t.integer :quantity
          end
        end

        teardown do
          @connection.drop_table "trades", if_exists: true rescue nil
          @connection.drop_table "purchases", if_exists: true rescue nil
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

          if current_adapter?(:PostgreSQLAdapter)
            begin
              # Test that complex expression is correctly parsed from the database
              @connection.add_check_constraint(:trades,
                "CASE WHEN price IS NOT NULL THEN true ELSE false END", name: "price_is_required")

              constraint = @connection.check_constraints("trades").find { |c| c.name == "price_is_required" }
              assert_includes constraint.expression, "WHEN price IS NOT NULL"
            ensure
              @connection.remove_check_constraint(:trades, name: "price_is_required")
            end
          end
        end

        if current_adapter?(:PostgreSQLAdapter)
          def test_check_constraints_scoped_to_schemas
            @connection.add_check_constraint :trades, "quantity > 0"

            assert_no_changes -> { @connection.check_constraints("trades").size } do
              @connection.create_schema "test_schema"
              @connection.create_table "test_schema.trades" do |t|
                t.integer :quantity
              end
              @connection.add_check_constraint "test_schema.trades", "quantity > 0"
            end
          ensure
            @connection.drop_schema "test_schema"
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

        if supports_non_unique_constraint_name?
          def test_add_constraint_with_same_name_to_different_table
            @connection.add_check_constraint :trades, "quantity > 0", name: "greater_than_zero"
            @connection.add_check_constraint :purchases, "quantity > 0", name: "greater_than_zero"

            trades_check_constraints = @connection.check_constraints("trades")
            assert_equal 1, trades_check_constraints.size
            trade_constraint = trades_check_constraints.first
            assert_equal "trades", trade_constraint.table_name
            assert_equal "greater_than_zero", trade_constraint.name

            purchases_check_constraints = @connection.check_constraints("purchases")
            assert_equal 1, purchases_check_constraints.size
            purchase_constraint = purchases_check_constraints.first
            assert_equal "purchases", purchase_constraint.table_name
            assert_equal "greater_than_zero", purchase_constraint.name
          end
        end

        def test_add_check_constraint_with_non_existent_table_raises
          e = assert_raises(ActiveRecord::StatementInvalid) do
            @connection.add_check_constraint :refunds, "quantity > 0", name: "quantity_check"
          end
          assert_match(/refunds/, e.message)
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

        def test_add_constraint_from_change_table_with_options
          @connection.change_table :trades do |t|
            t.check_constraint "price > 0", name: "price_check"
          end

          constraint = @connection.check_constraints("trades").first
          assert_equal "trades", constraint.table_name
          assert_equal "price_check", constraint.name
        end

        def test_remove_constraint_from_change_table_with_options
          @connection.add_check_constraint :trades, "price > 0", name: "price_check"

          @connection.change_table :trades do |t|
            t.remove_check_constraint "price > 0", name: "price_check"
          end

          assert_equal 0, @connection.check_constraints("trades").size
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
