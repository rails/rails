# frozen_string_literal: true

require "cases/helper"
require "models/post"

class SQLite3AnnotateTest < ActiveRecord::SQLite3TestCase
  fixtures :posts

  def test_annotate_wraps_content_in_an_inline_comment
    assert_sql(%r{\ASELECT "posts"\."id" FROM "posts" /\* foo \*/}) do
      posts = Post.select(:id).annotate("foo")
      assert posts.first
    end
  end

  def test_annotate_is_sanitized
    assert_sql(%r{\ASELECT "posts"\."id" FROM "posts" /\* foo \*/}) do
      posts = Post.select(:id).annotate("*/foo/*")
      assert posts.first
    end

    assert_sql(%r{\ASELECT "posts"\."id" FROM "posts" /\* foo \*/}) do
      posts = Post.select(:id).annotate("**//foo//**")
      assert posts.first
    end

    assert_sql(%r{\ASELECT "posts"\."id" FROM "posts" /\* foo \*/ /\* bar \*/}) do
      posts = Post.select(:id).annotate("*/foo/*").annotate("*/bar")
      assert posts.first
    end

    assert_sql(%r{\ASELECT "posts"\."id" FROM "posts" /\* \+ MAX_EXECUTION_TIME\(1\) \*/}) do
      posts = Post.select(:id).annotate("+ MAX_EXECUTION_TIME(1)")
      assert posts.first
    end
  end
end
