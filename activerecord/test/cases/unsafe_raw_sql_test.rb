# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

class UnsafeRawSqlTest < ActiveRecord::TestCase
  fixtures :posts, :comments

  test "order: allows string column name" do
    enabled, disabled = with_configs(:enabled, :disabled) do
      Post.order("title").pluck(:id)
    end

    assert_equal enabled, disabled
    assert_equal disabled, Post.unsafe_raw_order("title").pluck(:id)
  end

  test "order: allows symbol column name" do
    enabled, disabled = with_configs(:enabled, :disabled) do
      Post.order(:title).pluck(:id)
    end

    assert_equal enabled, disabled
    assert_equal disabled, Post.unsafe_raw_order(:title).pluck(:id)
  end

  test "order: allows downcase symbol direction" do
    enabled, disabled = with_configs(:enabled, :disabled) do
      Post.order(title: :asc).pluck(:id)
    end

    assert_equal enabled, disabled
    assert_equal disabled, Post.unsafe_raw_order(title: :asc).pluck(:id)
  end

  test "order: allows upcase symbol direction" do
    enabled, disabled = with_configs(:enabled, :disabled) do
      Post.order(title: :ASC).pluck(:id)
    end

    assert_equal enabled, disabled
    assert_equal disabled, Post.unsafe_raw_order(title: :ASC).pluck(:id)
  end

  test "order: allows string direction" do
    enabled, disabled = with_configs(:enabled, :disabled) do
      Post.order(title: "asc").pluck(:id)
    end

    assert_equal enabled, disabled
    assert_equal disabled, Post.unsafe_raw_order(title: "asc").pluck(:id)
  end

  test "order: allows multiple columns" do
    enabled, disabled = with_configs(:enabled, :disabled) do
      Post.order(:author_id, :title).pluck(:id)
    end

    assert_equal enabled, disabled
    assert_equal disabled, Post.unsafe_raw_order(:author_id, :title).pluck(:id)
  end

  test "order: allows mixed" do
    enabled, disabled = with_configs(:enabled, :disabled) do
      Post.order(:author_id, title: :asc).pluck(:id)
    end

    assert_equal enabled, disabled
    assert_equal disabled, Post.unsafe_raw_order(:author_id, title: :asc).pluck(:id)
  end

  test "order: disallows invalid column name" do
    with_config(:disabled) do
      assert_raises(ArgumentError) do
        Post.order("title asc").pluck(:id)
      end
    end
  end

  test "order: disallows invalid direction" do
    with_config(:disabled) do
      assert_raises(ArgumentError) do
        Post.order(title: :foo).pluck(:id)
      end
    end
  end

  test "order: disallows invalid column with direction" do
    with_config(:disabled) do
      assert_raises(ArgumentError) do
        Post.order(foo: :asc).pluck(:id)
      end
    end
  end

  test "pluck: allows string column name" do
    enabled, disabled = with_configs(:enabled, :disabled) do
      Post.pluck("title")
    end

    assert_equal enabled, disabled
    assert_equal disabled, Post.unsafe_raw_pluck("title")
  end

  test "pluck: allows symbol column name" do
    enabled, disabled = with_configs(:enabled, :disabled) do
      Post.pluck(:title)
    end

    assert_equal enabled, disabled
    assert_equal disabled, Post.unsafe_raw_pluck(:title)
  end

  test "pluck: allows multiple column names" do
    enabled, disabled = with_configs(:enabled, :disabled) do
      Post.pluck(:title, :id)
    end

    assert_equal enabled, disabled
    assert_equal disabled, Post.unsafe_raw_pluck(:title, :id)
  end

  test "pluck: allows column names with includes" do
    enabled, disabled = with_configs(:enabled, :disabled) do
      Post.includes(:comments).pluck(:title, :id)
    end

    assert_equal enabled, disabled
    assert_equal disabled, Post.includes(:comments).unsafe_raw_pluck(:title, :id)
  end

  test "pluck: allows auto-generated attributes" do
    enabled, disabled = with_configs(:enabled, :disabled) do
      Post.pluck(:tags_count)
    end

    assert_equal enabled, disabled
    assert_equal disabled, Post.unsafe_raw_pluck(:tags_count)
  end

  test "pluck: disallows invalid column name" do
    with_config(:disabled) do
      assert_raises(ArgumentError) do
        Post.pluck("length(title)")
      end
    end
  end

  test "pluck: disallows invalid column name amongst valid names" do
    with_config(:disabled) do
      assert_raises(ArgumentError) do
        Post.pluck(:title, "length(title)")
      end
    end
  end

  test "pluck: disallows invalid column names with includes" do
    with_config(:disabled) do
      assert_raises(ArgumentError) do
        Post.includes(:comments).pluck(:title, "length(title)")
      end
    end
  end

  def with_configs(*new_values, &blk)
    new_values.map { |nv| with_config(nv, &blk) }
  end

  def with_config(new_value, &blk)
    old_value = ActiveRecord::Base.allow_unsafe_raw_sql
    ActiveRecord::Base.allow_unsafe_raw_sql = new_value
    blk.call
  ensure
    ActiveRecord::Base.allow_unsafe_raw_sql = old_value
  end
end
