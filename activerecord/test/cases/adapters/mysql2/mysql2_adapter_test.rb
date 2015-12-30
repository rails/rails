require "cases/helper"

class Mysql2AdapterTest < ActiveRecord::Mysql2TestCase
  def setup
    @conn = ActiveRecord::Base.connection
  end

  def test_columns_for_distinct_zero_orders
    assert_equal "posts.id",
      @conn.columns_for_distinct("posts.id", [])
  end

  def test_columns_for_distinct_one_order
    assert_equal "posts.id, posts.created_at AS alias_0",
      @conn.columns_for_distinct("posts.id", ["posts.created_at desc"])
  end

  def test_columns_for_distinct_few_orders
    assert_equal "posts.id, posts.created_at AS alias_0, posts.position AS alias_1",
      @conn.columns_for_distinct("posts.id", ["posts.created_at desc", "posts.position asc"])
  end

  def test_columns_for_distinct_with_case
    assert_equal(
      'posts.id, CASE WHEN author.is_active THEN UPPER(author.name) ELSE UPPER(author.email) END AS alias_0',
      @conn.columns_for_distinct('posts.id',
        ["CASE WHEN author.is_active THEN UPPER(author.name) ELSE UPPER(author.email) END"])
    )
  end

  def test_columns_for_distinct_blank_not_nil_orders
    assert_equal "posts.id, posts.created_at AS alias_0",
      @conn.columns_for_distinct("posts.id", ["posts.created_at desc", "", "   "])
  end

  def test_columns_for_distinct_with_arel_order
    order = Object.new
    def order.to_sql
      "posts.created_at desc"
    end
    assert_equal "posts.id, posts.created_at AS alias_0",
      @conn.columns_for_distinct("posts.id", [order])
  end
end
