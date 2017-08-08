# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

class UnsafeRawSqlTest < ActiveRecord::TestCase
  fixtures :posts, :comments

  test "order: allows string column name" do
    ids_expected = Post.order(Arel.sql("title")).pluck(:id)

    ids_enabled  = with_unsafe_raw_sql_enabled  { Post.order("title").pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled { Post.order("title").pluck(:id) }

    assert_equal ids_expected, ids_enabled
    assert_equal ids_expected, ids_disabled
  end

  test "order: allows symbol column name" do
    ids_expected = Post.order(Arel.sql("title")).pluck(:id)

    ids_enabled  = with_unsafe_raw_sql_enabled  { Post.order(:title).pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled { Post.order(:title).pluck(:id) }

    assert_equal ids_expected, ids_enabled
    assert_equal ids_expected, ids_disabled
  end

  test "order: allows downcase symbol direction" do
    ids_expected = Post.order(Arel.sql("title") => Arel.sql("asc")).pluck(:id)

    ids_enabled  = with_unsafe_raw_sql_enabled  { Post.order(title: :asc).pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled { Post.order(title: :asc).pluck(:id) }

    assert_equal ids_expected, ids_enabled
    assert_equal ids_expected, ids_disabled
  end

  test "order: allows upcase symbol direction" do
    ids_expected = Post.order(Arel.sql("title") => Arel.sql("ASC")).pluck(:id)

    ids_enabled  = with_unsafe_raw_sql_enabled  { Post.order(title: :ASC).pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled { Post.order(title: :ASC).pluck(:id) }

    assert_equal ids_expected, ids_enabled
    assert_equal ids_expected, ids_disabled
  end

  test "order: allows string direction" do
    ids_expected = Post.order(Arel.sql("title") => Arel.sql("asc")).pluck(:id)

    ids_enabled  = with_unsafe_raw_sql_enabled  { Post.order(title: "asc").pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled { Post.order(title: "asc").pluck(:id) }

    assert_equal ids_expected, ids_enabled
    assert_equal ids_expected, ids_disabled
  end

  test "order: allows multiple columns" do
    ids_expected = Post.order(Arel.sql("author_id"), Arel.sql("title")).pluck(:id)

    ids_enabled  = with_unsafe_raw_sql_enabled  { Post.order(:author_id, :title).pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled { Post.order(:author_id, :title).pluck(:id) }

    assert_equal ids_expected, ids_enabled
    assert_equal ids_expected, ids_disabled
  end

  test "order: allows mixed" do
    ids_expected = Post.order(Arel.sql("author_id"), Arel.sql("title") => Arel.sql("asc")).pluck(:id)

    ids_enabled  = with_unsafe_raw_sql_enabled  { Post.order(:author_id, title: :asc).pluck(:id) }
    ids_disabled = with_unsafe_raw_sql_disabled { Post.order(:author_id, title: :asc).pluck(:id) }

    assert_equal ids_expected, ids_enabled
    assert_equal ids_expected, ids_disabled
  end

  test "order: disallows invalid column name" do
    with_unsafe_raw_sql_disabled do
      assert_raises(ActiveRecord::UnknownAttributeReference) do
        Post.order("title asc").pluck(:id)
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
        Post.order(foo: :asc).pluck(:id)
      end
    end
  end

  test "order: always allows Arel" do
    ids_enabled  = with_unsafe_raw_sql_enabled  { Post.order(Arel.sql("length(title)")).pluck(:title) }
    ids_disabled = with_unsafe_raw_sql_disabled { Post.order(Arel.sql("length(title)")).pluck(:title) }

    assert_equal ids_enabled, ids_disabled
  end

  test "order: logs deprecation warning for unrecognized column" do
    with_unsafe_raw_sql_deprecated do
      ActiveSupport::Deprecation.expects(:warn).with do |msg|
        msg =~ /\ADangerous query method used with .*length\(title\)/
      end

      Post.order("length(title)")
    end
  end

  test "pluck: allows string column name" do
    titles_expected = Post.pluck(Arel.sql("title"))

    titles_enabled  = with_unsafe_raw_sql_enabled  { Post.pluck("title") }
    titles_disabled = with_unsafe_raw_sql_disabled { Post.pluck("title") }

    assert_equal titles_expected, titles_enabled
    assert_equal titles_expected, titles_disabled
  end

  test "pluck: allows symbol column name" do
    titles_expected = Post.pluck(Arel.sql("title"))

    titles_enabled  = with_unsafe_raw_sql_enabled  { Post.pluck(:title) }
    titles_disabled = with_unsafe_raw_sql_disabled { Post.pluck(:title) }

    assert_equal titles_expected, titles_enabled
    assert_equal titles_expected, titles_disabled
  end

  test "pluck: allows multiple column names" do
    values_expected = Post.pluck(Arel.sql("title"), Arel.sql("id"))

    values_enabled  = with_unsafe_raw_sql_enabled  { Post.pluck(:title, :id) }
    values_disabled = with_unsafe_raw_sql_disabled { Post.pluck(:title, :id) }

    assert_equal values_expected, values_enabled
    assert_equal values_expected, values_disabled
  end

  test "pluck: allows column names with includes" do
    values_expected = Post.includes(:comments).pluck(Arel.sql("title"), Arel.sql("id"))

    values_enabled  = with_unsafe_raw_sql_enabled  { Post.includes(:comments).pluck(:title, :id) }
    values_disabled = with_unsafe_raw_sql_disabled { Post.includes(:comments).pluck(:title, :id) }

    assert_equal values_expected, values_enabled
    assert_equal values_expected, values_disabled
  end

  test "pluck: allows auto-generated attributes" do
    values_expected = Post.pluck(Arel.sql("tags_count"))

    values_enabled  = with_unsafe_raw_sql_enabled  { Post.pluck(:tags_count) }
    values_disabled = with_unsafe_raw_sql_disabled { Post.pluck(:tags_count) }

    assert_equal values_expected, values_enabled
    assert_equal values_expected, values_disabled
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
    values_enabled  = with_unsafe_raw_sql_enabled  { Post.includes(:comments).pluck(:title, Arel.sql("length(title)")) }
    values_disabled = with_unsafe_raw_sql_disabled { Post.includes(:comments).pluck(:title, Arel.sql("length(title)")) }

    assert_equal values_enabled, values_disabled
  end

  test "pluck: logs deprecation warning" do
    with_unsafe_raw_sql_deprecated do
      ActiveSupport::Deprecation.expects(:warn).with do |msg|
        msg =~ /\ADangerous query method used with .*length\(title\)/
      end

      Post.includes(:comments).pluck(:title, "length(title)")
    end
  end

  def with_unsafe_raw_sql_enabled(&blk)
    with_config(:enabled, &blk)
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
