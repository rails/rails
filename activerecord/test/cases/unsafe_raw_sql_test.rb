# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

class UnsafeRawSqlTest < ActiveRecord::TestCase
  fixtures :posts, :comments

  test "order: allows string column name" do
    ids_expected = Post.order(Arel.sql("title")).pluck(:id)

    ids_depr     = with_unsafe_raw_sql_deprecated { Post.order("title").pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled   { Post.order("title").pluck(:id) }

    assert_equal ids_expected, ids_depr
    assert_equal ids_expected, ids_disabled
  end

  test "order: allows symbol column name" do
    ids_expected = Post.order(Arel.sql("title")).pluck(:id)

    ids_depr     = with_unsafe_raw_sql_deprecated { Post.order(:title).pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled   { Post.order(:title).pluck(:id) }

    assert_equal ids_expected, ids_depr
    assert_equal ids_expected, ids_disabled
  end

  test "order: allows downcase symbol direction" do
    ids_expected = Post.order(Arel.sql("title") => Arel.sql("asc")).pluck(:id)

    ids_depr     = with_unsafe_raw_sql_deprecated { Post.order(title: :asc).pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled   { Post.order(title: :asc).pluck(:id) }

    assert_equal ids_expected, ids_depr
    assert_equal ids_expected, ids_disabled
  end

  test "order: allows upcase symbol direction" do
    ids_expected = Post.order(Arel.sql("title") => Arel.sql("ASC")).pluck(:id)

    ids_depr     = with_unsafe_raw_sql_deprecated { Post.order(title: :ASC).pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled   { Post.order(title: :ASC).pluck(:id) }

    assert_equal ids_expected, ids_depr
    assert_equal ids_expected, ids_disabled
  end

  test "order: allows string direction" do
    ids_expected = Post.order(Arel.sql("title") => Arel.sql("asc")).pluck(:id)

    ids_depr     = with_unsafe_raw_sql_deprecated { Post.order(title: "asc").pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled   { Post.order(title: "asc").pluck(:id) }

    assert_equal ids_expected, ids_depr
    assert_equal ids_expected, ids_disabled
  end

  test "order: allows multiple columns" do
    ids_expected = Post.order(Arel.sql("author_id"), Arel.sql("title")).pluck(:id)

    ids_depr     = with_unsafe_raw_sql_deprecated { Post.order(:author_id, :title).pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled   { Post.order(:author_id, :title).pluck(:id) }

    assert_equal ids_expected, ids_depr
    assert_equal ids_expected, ids_disabled
  end

  test "order: allows mixed" do
    ids_expected = Post.order(Arel.sql("author_id"), Arel.sql("title") => Arel.sql("asc")).pluck(:id)

    ids_depr     = with_unsafe_raw_sql_deprecated { Post.order(:author_id, title: :asc).pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled   { Post.order(:author_id, title: :asc).pluck(:id) }

    assert_equal ids_expected, ids_depr
    assert_equal ids_expected, ids_disabled
  end

  test "order: allows table and column name" do
    ids_expected = Post.order(Arel.sql("title")).pluck(:id)

    ids_depr     = with_unsafe_raw_sql_deprecated { Post.order("posts.title").pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled   { Post.order("posts.title").pluck(:id) }

    assert_equal ids_expected, ids_depr
    assert_equal ids_expected, ids_disabled
  end

  test "order: allows column name and direction in string" do
    ids_expected = Post.order(Arel.sql("title desc")).pluck(:id)

    ids_depr     = with_unsafe_raw_sql_deprecated { Post.order("title desc").pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled   { Post.order("title desc").pluck(:id) }

    assert_equal ids_expected, ids_depr
    assert_equal ids_expected, ids_disabled
  end

  test "order: allows table name, column name and direction in string" do
    ids_expected = Post.order(Arel.sql("title desc")).pluck(:id)

    ids_depr     = with_unsafe_raw_sql_deprecated { Post.order("posts.title desc").pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled   { Post.order("posts.title desc").pluck(:id) }

    assert_equal ids_expected, ids_depr
    assert_equal ids_expected, ids_disabled
  end

  test "order: allows NULLS FIRST and NULLS LAST too" do
    raise "precondition failed" if Post.count < 2

    # Ensure there are NULL and non-NULL post types.
    Post.first.update_column(:type, nil)
    Post.last.update_column(:type, "Programming")

    ["asc", "desc", ""].each do |direction|
      %w(first last).each do |position|
        ids_expected = Post.order(Arel.sql("type #{direction} nulls #{position}")).pluck(:id)

        ids_depr     = with_unsafe_raw_sql_deprecated { Post.order("type #{direction} nulls #{position}").pluck(:id) }
        ids_disabled = with_unsafe_raw_sql_disabled   { Post.order("type #{direction} nulls #{position}").pluck(:id) }

        assert_equal ids_expected, ids_depr
        assert_equal ids_expected, ids_disabled
      end
    end
  end if current_adapter?(:PostgreSQLAdapter)

  test "order: disallows invalid column name" do
    with_unsafe_raw_sql_disabled do
      assert_raises(ActiveRecord::UnknownAttributeReference) do
        Post.order("len(title) asc").pluck(:id)
      end
    end
  end

  test "order: disallows invalid direction" do
    with_unsafe_raw_sql_disabled do
      assert_raises(ArgumentError) do
        Post.order(title: :foo).pluck(:id)
      end
    end
  end

  test "order: disallows invalid column with direction" do
    with_unsafe_raw_sql_disabled do
      assert_raises(ActiveRecord::UnknownAttributeReference) do
        Post.order("len(title)" => :asc).pluck(:id)
      end
    end
  end

  test "order: always allows Arel" do
    ids_depr     = with_unsafe_raw_sql_deprecated { Post.order(Arel.sql("length(title)")).pluck(:title) }
    ids_disabled = with_unsafe_raw_sql_disabled   { Post.order(Arel.sql("length(title)")).pluck(:title) }

    assert_equal ids_depr, ids_disabled
  end

  test "order: allows Arel.sql with binds" do
    ids_expected = Post.order(Arel.sql("REPLACE(title, 'misc', 'zzzz'), id")).pluck(:id)

    ids_depr     = with_unsafe_raw_sql_deprecated { Post.order([Arel.sql("REPLACE(title, ?, ?), id"), "misc", "zzzz"]).pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled   { Post.order([Arel.sql("REPLACE(title, ?, ?), id"), "misc", "zzzz"]).pluck(:id) }

    assert_equal ids_expected, ids_depr
    assert_equal ids_expected, ids_disabled
  end

  test "order: disallows invalid bind statement" do
    with_unsafe_raw_sql_disabled do
      assert_raises(ActiveRecord::UnknownAttributeReference) do
        Post.order(["REPLACE(title, ?, ?), id", "misc", "zzzz"]).pluck(:id)
      end
    end
  end

  test "order: disallows invalid Array arguments" do
    with_unsafe_raw_sql_disabled do
      assert_raises(ActiveRecord::UnknownAttributeReference) do
        Post.order(["author_id", "length(title)"]).pluck(:id)
      end
    end
  end

  test "order: allows valid Array arguments" do
    ids_expected = Post.order(Arel.sql("author_id, length(title)")).pluck(:id)

    ids_depr     = with_unsafe_raw_sql_deprecated { Post.order(["author_id", Arel.sql("length(title)")]).pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled   { Post.order(["author_id", Arel.sql("length(title)")]).pluck(:id) }

    assert_equal ids_expected, ids_depr
    assert_equal ids_expected, ids_disabled
  end

  test "order: logs deprecation warning for unrecognized column" do
    with_unsafe_raw_sql_deprecated do
      assert_deprecated(/Dangerous query method/) do
        Post.order("length(title)")
      end
    end
  end

  test "pluck: allows string column name" do
    titles_expected = Post.pluck(Arel.sql("title"))

    titles_depr     = with_unsafe_raw_sql_deprecated { Post.pluck("title") }
    titles_disabled = with_unsafe_raw_sql_disabled   { Post.pluck("title") }

    assert_equal titles_expected, titles_depr
    assert_equal titles_expected, titles_disabled
  end

  test "pluck: allows symbol column name" do
    titles_expected = Post.pluck(Arel.sql("title"))

    titles_depr     = with_unsafe_raw_sql_deprecated { Post.pluck(:title) }
    titles_disabled = with_unsafe_raw_sql_disabled   { Post.pluck(:title) }

    assert_equal titles_expected, titles_depr
    assert_equal titles_expected, titles_disabled
  end

  test "pluck: allows multiple column names" do
    values_expected = Post.pluck(Arel.sql("title"), Arel.sql("id"))

    values_depr     = with_unsafe_raw_sql_deprecated { Post.pluck(:title, :id) }
    values_disabled = with_unsafe_raw_sql_disabled   { Post.pluck(:title, :id) }

    assert_equal values_expected, values_depr
    assert_equal values_expected, values_disabled
  end

  test "pluck: allows column names with includes" do
    values_expected = Post.includes(:comments).pluck(Arel.sql("title"), Arel.sql("id"))

    values_depr     = with_unsafe_raw_sql_deprecated { Post.includes(:comments).pluck(:title, :id) }
    values_disabled = with_unsafe_raw_sql_disabled   { Post.includes(:comments).pluck(:title, :id) }

    assert_equal values_expected, values_depr
    assert_equal values_expected, values_disabled
  end

  test "pluck: allows auto-generated attributes" do
    values_expected = Post.pluck(Arel.sql("tags_count"))

    values_depr     = with_unsafe_raw_sql_deprecated { Post.pluck(:tags_count) }
    values_disabled = with_unsafe_raw_sql_disabled   { Post.pluck(:tags_count) }

    assert_equal values_expected, values_depr
    assert_equal values_expected, values_disabled
  end

  test "pluck: allows table and column names" do
    titles_expected = Post.pluck(Arel.sql("title"))

    titles_depr     = with_unsafe_raw_sql_deprecated { Post.pluck("posts.title") }
    titles_disabled = with_unsafe_raw_sql_disabled   { Post.pluck("posts.title") }

    assert_equal titles_expected, titles_depr
    assert_equal titles_expected, titles_disabled
  end

  test "pluck: disallows invalid column name" do
    with_unsafe_raw_sql_disabled do
      assert_raises(ActiveRecord::UnknownAttributeReference) do
        Post.pluck("length(title)")
      end
    end
  end

  test "pluck: disallows invalid column name amongst valid names" do
    with_unsafe_raw_sql_disabled do
      assert_raises(ActiveRecord::UnknownAttributeReference) do
        Post.pluck(:title, "length(title)")
      end
    end
  end

  test "pluck: disallows invalid column names with includes" do
    with_unsafe_raw_sql_disabled do
      assert_raises(ActiveRecord::UnknownAttributeReference) do
        Post.includes(:comments).pluck(:title, "length(title)")
      end
    end
  end

  test "pluck: always allows Arel" do
    values_depr     = with_unsafe_raw_sql_deprecated { Post.includes(:comments).pluck(:title, Arel.sql("length(title)")) }
    values_disabled = with_unsafe_raw_sql_disabled   { Post.includes(:comments).pluck(:title, Arel.sql("length(title)")) }

    assert_equal values_depr, values_disabled
  end

  test "pluck: logs deprecation warning" do
    with_unsafe_raw_sql_deprecated do
      assert_deprecated(/Dangerous query method/) do
        Post.includes(:comments).pluck(:title, "length(title)")
      end
    end
  end

  def with_unsafe_raw_sql_disabled(&blk)
    with_config(:disabled, &blk)
  end

  def with_unsafe_raw_sql_deprecated(&blk)
    with_config(:deprecated, &blk)
  end

  def with_config(new_value, &blk)
    old_value = ActiveRecord::Base.allow_unsafe_raw_sql
    ActiveRecord::Base.allow_unsafe_raw_sql = new_value
    blk.call
  ensure
    ActiveRecord::Base.allow_unsafe_raw_sql = old_value
  end
end
