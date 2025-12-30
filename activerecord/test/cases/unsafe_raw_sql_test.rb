# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

class UnsafeRawSqlTest < ActiveRecord::TestCase
  fixtures :posts, :comments

  test "order: allows string column name" do
    ids_expected = Post.order(Arel.sql("title")).pluck(:id)

    ids = Post.order("title").pluck(:id)

    assert_equal ids_expected, ids
  end

  test "order: allows symbol column name" do
    ids_expected = Post.order(Arel.sql("title")).pluck(:id)

    ids = Post.order(:title).pluck(:id)

    assert_equal ids_expected, ids
  end

  test "order: allows downcase symbol direction" do
    ids_expected = Post.order(Arel.sql("title") => Arel.sql("asc")).pluck(:id)

    ids = Post.order(title: :asc).pluck(:id)

    assert_equal ids_expected, ids
  end

  test "order: allows upcase symbol direction" do
    ids_expected = Post.order(Arel.sql("title") => Arel.sql("ASC")).pluck(:id)

    ids = Post.order(title: :ASC).pluck(:id)

    assert_equal ids_expected, ids
  end

  test "order: allows string direction" do
    ids_expected = Post.order(Arel.sql("title") => Arel.sql("asc")).pluck(:id)

    ids = Post.order(title: "asc").pluck(:id)

    assert_equal ids_expected, ids
  end

  test "order: allows multiple columns" do
    ids_expected = Post.order(Arel.sql("author_id"), Arel.sql("title")).pluck(:id)

    ids = Post.order(:author_id, :title).pluck(:id)

    assert_equal ids_expected, ids
  end

  test "order: allows mixed" do
    ids_expected = Post.order(Arel.sql("author_id"), Arel.sql("title") => Arel.sql("asc")).pluck(:id)

    ids = Post.order(:author_id, title: :asc).pluck(:id)

    assert_equal ids_expected, ids
  end

  test "order: allows table and column names" do
    ids_expected = Post.order(Arel.sql("title")).pluck(:id)

    ids = Post.order("posts.title").pluck(:id)

    assert_equal ids_expected, ids
  end

  test "order: allows quoted table and column names" do
    ids_expected = Post.order(Arel.sql("title")).pluck(:id)

    ids = Post.order(quote_table_name("posts.title")).pluck(:id)

    assert_equal ids_expected, ids
  end

  test "order: allows column name and direction in string" do
    ids_expected = Post.order(Arel.sql("title desc")).pluck(:id)

    ids = Post.order("title desc").pluck(:id)

    assert_equal ids_expected, ids
  end

  test "order: allows table name, column name and direction in string" do
    ids_expected = Post.order(Arel.sql("title desc")).pluck(:id)

    ids = Post.order("posts.title desc").pluck(:id)

    assert_equal ids_expected, ids
  end

  test "order: allows NULLS FIRST and NULLS LAST too" do
    raise "precondition failed" if Post.count < 2

    # Ensure there are NULL and non-NULL post types.
    Post.first.update_column(:type, nil)
    Post.last.update_column(:type, "Programming")

    ["asc", "desc", ""].each do |direction|
      %w(first last).each do |position|
        ids_expected = Post.order(Arel.sql("type::text #{direction} nulls #{position}")).pluck(:id)

        ids = Post.order("type::text #{direction} nulls #{position}").pluck(:id)

        assert_equal ids_expected, ids
      end
    end
  end if current_adapter?(:PostgreSQLAdapter)

  test "order: disallows invalid column name" do
    assert_raises(ActiveRecord::UnknownAttributeReference) do
      Post.order("REPLACE(title, 'misc', 'zzzz') asc").pluck(:id)
    end
  end

  test "order: disallows invalid direction" do
    assert_raises(ArgumentError) do
      Post.order(title: :foo).pluck(:id)
    end
  end

  test "order: disallows invalid column with direction" do
    assert_raises(ActiveRecord::UnknownAttributeReference) do
      Post.order("REPLACE(title, 'misc', 'zzzz')" => :asc).pluck(:id)
    end
  end

  test "order: always allows Arel" do
    titles = Post.order(Arel.sql("length(title)")).pluck(:title)

    assert_not_empty titles
  end

  test "order: allows Arel.sql with binds" do
    ids_expected = Post.order(Arel.sql("REPLACE(title, 'misc', 'zzzz'), id")).pluck(:id)

    ids = Post.order([Arel.sql("REPLACE(title, ?, ?), id"), "misc", "zzzz"]).pluck(:id)

    assert_equal ids_expected, ids
  end

  test "order: disallows invalid bind statement" do
    assert_raises(ActiveRecord::UnknownAttributeReference) do
      Post.order(["REPLACE(title, ?, ?), id", "misc", "zzzz"]).pluck(:id)
    end
  end

  test "order: disallows invalid Array arguments" do
    assert_raises(ActiveRecord::UnknownAttributeReference) do
      Post.order(["author_id", "REPLACE(title, 'misc', 'zzzz')"]).pluck(:id)
    end
  end

  test "order: allows valid Array arguments" do
    ids_expected = Post.order(Arel.sql("author_id, length(title)")).pluck(:id)

    ids = Post.order(["author_id", "length(title)"]).pluck(:id)

    assert_equal ids_expected, ids
  end

  test "order: allows valid arguments with COLLATE" do
    collation_name = {
      "PostgreSQL" => "C",
      "Mysql2" => "utf8mb4_bin",
      "Trilogy" => "utf8mb4_bin",
      "SQLite" => "binary"
    }[ActiveRecord::Base.lease_connection.adapter_name]

    ids_expected = Post.order(Arel.sql(%Q'author_id, title COLLATE "#{collation_name}" DESC')).pluck(:id)

    ids = Post.order(["author_id", %Q'title COLLATE "#{collation_name}" DESC']).pluck(:id)

    assert_equal ids_expected, ids
  end

  test "order: allows nested functions" do
    ids_expected = Post.order(Arel.sql("author_id, length(trim(title))")).pluck(:id)

    ids = Post.order("author_id, length(trim(title))").pluck(:id)

    assert_equal ids_expected, ids
  end

  test "order: disallows dangerous query method" do
    e = assert_raises(ActiveRecord::UnknownAttributeReference) do
      Post.order("REPLACE(title, 'misc', 'zzzz')")
    end

    assert_match(/Dangerous query method \(method whose arguments are used as raw SQL\) called with non-attribute argument\(s\):/, e.message)
  end

  test "pluck: allows string column name" do
    titles_expected = Post.pluck(Arel.sql("title"))

    titles = Post.pluck("title")

    assert_equal titles_expected, titles
  end

  test "pluck: allows string column name with function and alias" do
    titles_expected = Post.pluck(Arel.sql("UPPER(title)"))

    titles = Post.pluck("UPPER(title) AS title")

    assert_equal titles_expected, titles
  end

  test "pluck: allows symbol column name" do
    titles_expected = Post.pluck(Arel.sql("title"))

    titles = Post.pluck(:title)

    assert_equal titles_expected, titles
  end

  test "pluck: allows multiple column names" do
    values_expected = Post.pluck(Arel.sql("title"), Arel.sql("id"))

    values = Post.pluck(:title, :id)

    assert_equal values_expected, values
  end

  test "pluck: allows column names with includes" do
    values_expected = Post.includes(:comments).pluck(Arel.sql("title"), Arel.sql("id"))

    values = Post.includes(:comments).pluck(:title, :id)

    assert_equal values_expected, values
  end

  test "pluck: allows auto-generated attributes" do
    values_expected = Post.pluck(Arel.sql("tags_count"))

    values = Post.pluck(:tags_count)

    assert_equal values_expected, values
  end

  test "pluck: allows table and column names" do
    titles_expected = Post.pluck(Arel.sql("title"))

    titles = Post.pluck("posts.title")

    assert_equal titles_expected, titles
  end

  test "pluck: allows quoted table and column names" do
    titles_expected = Post.pluck(Arel.sql("title"))

    titles = Post.pluck(quote_table_name("posts.title"))

    assert_equal titles_expected, titles
  end

  test "pluck: allows nested functions" do
    title_lengths_expected = Post.pluck(Arel.sql("length(trim(title))"))

    title_lengths = Post.pluck("length(trim(title))")

    assert_equal title_lengths_expected, title_lengths
  end

  test "pluck: disallows invalid column name" do
    assert_raises(ActiveRecord::UnknownAttributeReference) do
      Post.pluck("REPLACE(title, 'misc', 'zzzz')")
    end
  end

  test "pluck: disallows invalid column name amongst valid names" do
    assert_raises(ActiveRecord::UnknownAttributeReference) do
      Post.pluck(:title, "REPLACE(title, 'misc', 'zzzz')")
    end
  end

  test "pluck: disallows invalid column names with includes" do
    assert_raises(ActiveRecord::UnknownAttributeReference) do
      Post.includes(:comments).pluck(:title, "REPLACE(title, 'misc', 'zzzz')")
    end
  end

  test "pluck: always allows Arel" do
    excepted_values = Post.includes(:comments).pluck(:title).map { |title| [title, title.size] }
    values = Post.includes(:comments).pluck(:title, Arel.sql("length(title)"))

    assert_equal excepted_values, values
  end

  test "pluck: disallows dangerous query method" do
    e = assert_raises(ActiveRecord::UnknownAttributeReference) do
      Post.includes(:comments).pluck(:title, "REPLACE(title, 'misc', 'zzzz')")
    end

    assert_match(/Dangerous query method \(method whose arguments are used as raw SQL\) called with non-attribute argument\(s\):/, e.message)
  end
end
