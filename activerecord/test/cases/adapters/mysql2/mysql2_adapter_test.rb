# frozen_string_literal: true

require "cases/helper"
require "support/ddl_helper"

class Mysql2AdapterTest < ActiveRecord::Mysql2TestCase
  include DdlHelper

  def setup
    @conn = ActiveRecord::Base.connection
  end

  def test_exec_query_nothing_raises_with_no_result_queries
    assert_nothing_raised do
      with_example_table do
        @conn.exec_query("INSERT INTO ex (number) VALUES (1)")
        @conn.exec_query("DELETE FROM ex WHERE number = 1")
      end
    end
  end

  def test_columns_for_distinct_zero_orders
    assert_equal "posts.id",
      @conn.columns_for_distinct("posts.id", [])
  end

  def test_columns_for_distinct_one_order
    assert_equal "posts.created_at AS alias_0, posts.id",
      @conn.columns_for_distinct("posts.id", ["posts.created_at desc"])
  end

  def test_columns_for_distinct_few_orders
    assert_equal "posts.created_at AS alias_0, posts.position AS alias_1, posts.id",
      @conn.columns_for_distinct("posts.id", ["posts.created_at desc", "posts.position asc"])
  end

  def test_columns_for_distinct_with_case
    assert_equal(
      "CASE WHEN author.is_active THEN UPPER(author.name) ELSE UPPER(author.email) END AS alias_0, posts.id",
      @conn.columns_for_distinct("posts.id",
        ["CASE WHEN author.is_active THEN UPPER(author.name) ELSE UPPER(author.email) END"])
    )
  end

  def test_columns_for_distinct_blank_not_nil_orders
    assert_equal "posts.created_at AS alias_0, posts.id",
      @conn.columns_for_distinct("posts.id", ["posts.created_at desc", "", "   "])
  end

  def test_columns_for_distinct_with_arel_order
    order = Object.new
    def order.to_sql
      "posts.created_at desc"
    end
    assert_equal "posts.created_at AS alias_0, posts.id",
      @conn.columns_for_distinct("posts.id", [order])
  end

  def test_errors_for_bigint_fks_on_integer_pk_table
    # table old_cars has primary key of integer

    error = assert_raises(ActiveRecord::MismatchedForeignKey) do
      @conn.add_reference :engines, :old_car
      @conn.add_foreign_key :engines, :old_cars
    end

    assert_match "Column `old_car_id` on table `engines` has a type of `bigint(20)`", error.message
    assert_not_nil error.cause
    @conn.exec_query("ALTER TABLE engines DROP COLUMN old_car_id")
  end

  private

    def with_example_table(definition = "id int auto_increment primary key, number int, data varchar(255)", &block)
      super(@conn, "ex", definition, &block)
    end
end
