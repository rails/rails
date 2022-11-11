# frozen_string_literal: true

require "cases/helper"
require "models/post"

class SQLite3SanitizeTest < ActiveRecord::SQLite3TestCase
  def test_sanitize_sql_for_conditions
    actual = ActiveRecord::Base.sanitize_sql_for_conditions(["name=? AND group_id=?", "foo'bar", 4])
    expected = "name='foo''bar' AND group_id=4"
    assert_equal expected, actual

    actual = ActiveRecord::Base.sanitize_sql_for_conditions(["name=:name AND group_id=:group_id", name: "foo'bar", group_id: 4])
    expected = "name='foo''bar' AND group_id=4"
    assert_equal expected, actual

    actual = ActiveRecord::Base.sanitize_sql_for_conditions(["name='%s' AND group_id='%s'", "foo'bar", 4])
    expected = "name='foo''bar' AND group_id='4'"
    assert_equal expected, actual

    actual = ActiveRecord::Base.sanitize_sql_for_conditions("name='foo''bar' AND group_id='4'")
    expected = "name='foo''bar' AND group_id='4'"
    assert_equal expected, actual
  end

  def test_sanitize_sql_for_assignment
    actual = Post.sanitize_sql_for_assignment(["name=? AND group_id=?", nil, 4])
    expected = "name=NULL AND group_id=4"
    assert_equal expected, actual

    actual = Post.sanitize_sql_for_assignment(["name=:name AND group_id=:group_id", name: nil, group_id: 4])
    expected = "name=NULL AND group_id=4"
    assert_equal expected, actual

    actual = Post.sanitize_sql_for_assignment({ name: nil, group_id: 4 })
    expected = "\"name\" = NULL, \"group_id\" = 4"
    assert_equal expected, actual

    actual = Post.sanitize_sql_for_assignment("name=NULL AND group_id='4'")
    expected = "name=NULL AND group_id='4'"
    assert_equal expected, actual
  end

  def test_sanitize_sql_for_order
    actual = Post.sanitize_sql_for_order([Arel.sql("FIELD(id, ?)"), [1, 3, 2]])
    expected = "FIELD(id, 1,3,2)"
    assert_equal expected, actual

    actual = Post.sanitize_sql_for_order([
      Arel.sql("FIELD(val, ?)"),
      [Arel.sql(1, bypass_numeric_quoting: true), Arel.sql(3, bypass_numeric_quoting: true), Arel.sql(2, bypass_numeric_quoting: true)]
    ])
    expected = "FIELD(val, 1,3,2)"
    assert_equal expected, actual

    actual = Post.sanitize_sql_for_order("id ASC")
    expected = "id ASC"
    assert_equal expected, actual
  end

  def test_sanitize_sql_hash_for_assignment
    actual = Post.sanitize_sql_hash_for_assignment({ status: nil, group_id: 1 }, "posts")
    expected = "\"status\" = NULL, \"group_id\" = 1"
    assert_equal expected, actual
  end

  def test_sanitize_sql_like
    actual = ActiveRecord::Base.sanitize_sql_like("100%")
    expected = "100\\%"
    assert_equal expected, actual

    actual = ActiveRecord::Base.sanitize_sql_like("snake_cased_string")
    expected = "snake\\_cased\\_string"
    assert_equal expected, actual

    actual = ActiveRecord::Base.sanitize_sql_like("100%", "!")
    expected = "100!%"
    assert_equal expected, actual

    actual = ActiveRecord::Base.sanitize_sql_like("snake_cased_string", "!")
    expected = "snake!_cased!_string"
    assert_equal expected, actual
  end

  def test_sanitize_sql_array
    actual = ActiveRecord::Base.sanitize_sql_array(["name=? AND group_id=?", "foo'bar", 4])
    expected = "name='foo''bar' AND group_id=4"
    assert_equal expected, actual

    actual = ActiveRecord::Base.sanitize_sql_array(["name=:name AND group_id=:group_id", name: "foo'bar", group_id: 4])
    expected = "name='foo''bar' AND group_id=4"
    assert_equal expected, actual

    actual = ActiveRecord::Base.sanitize_sql_array(["name='%s' AND group_id='%s'", "foo'bar", 4])
    expected = "name='foo''bar' AND group_id='4'"
    assert_equal expected, actual
  end
end
