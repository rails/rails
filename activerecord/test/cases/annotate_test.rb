# frozen_string_literal: true

require "cases/helper"
require "models/post"

class AnnotateTest < ActiveRecord::TestCase
  fixtures :posts

  def test_annotate_wraps_content_in_an_inline_comment
    quoted_posts_id = Regexp.escape(quote_table_name("posts.id"))
    quoted_posts = Regexp.escape(quote_table_name("posts"))

    assert_queries_match(%r{SELECT #{quoted_posts_id} FROM #{quoted_posts} /\* foo \*/}i) do
      posts = Post.select(:id).annotate("foo")
      assert posts.first
    end
  end

  def test_annotate_is_sanitized
    quoted_posts_id = Regexp.escape(quote_table_name("posts.id"))
    quoted_posts = Regexp.escape(quote_table_name("posts"))

    assert_queries_match(%r{SELECT #{quoted_posts_id} FROM #{quoted_posts} /\* \* /foo/ \* \*/}i) do
      posts = Post.select(:id).annotate("*/foo/*")
      assert posts.first
    end

    assert_queries_match(%r{SELECT #{quoted_posts_id} FROM #{quoted_posts} /\* \*\* //foo// \*\* \*/}i) do
      posts = Post.select(:id).annotate("**//foo//**")
      assert posts.first
    end

    assert_queries_match(%r{SELECT #{quoted_posts_id} FROM #{quoted_posts} /\* \* \* //foo// \* \* \*/}i) do
      posts = Post.select(:id).annotate("* *//foo//* *")
      assert posts.first
    end

    assert_queries_match(%r{SELECT #{quoted_posts_id} FROM #{quoted_posts} /\* \* /foo/ \* \*/ /\* \* /bar \*/}i) do
      posts = Post.select(:id).annotate("*/foo/*").annotate("*/bar")
      assert posts.first
    end

    assert_queries_match(%r{SELECT #{quoted_posts_id} FROM #{quoted_posts} /\* \+ MAX_EXECUTION_TIME\(1\) \*/}i) do
      posts = Post.select(:id).annotate("+ MAX_EXECUTION_TIME(1)")
      assert posts.first
    end
  end
end
