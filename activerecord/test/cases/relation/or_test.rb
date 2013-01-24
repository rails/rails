require "cases/helper"
require 'models/post'

module ActiveRecord
  class OrTest < ActiveRecord::TestCase
    fixtures :posts

    def test_or_with_relation
      expected = Post.where('id = 1 or id = 2').to_a
      assert_equal expected, Post.where('id = 1').or(Post.where('id = 2')).to_a
    end

    def test_or_with_string
      expected = Post.where('id = 1 or id = 2').to_a
      assert_equal expected, Post.where('id = 1').or('id = 2').to_a
    end

    def test_or_chaining
      expected = Post.where('id = 1 or id = 2').to_a
      assert_equal expected, Post.where('id = 1').or.where('id = 2').to_a
    end

    def test_or_without_left_where
      expected = Post.where('id = 1').to_a
      assert_equal expected, Post.or('id = 1').to_a
    end

    def test_or_without_right_where
      expected = Post.where('id = 1').to_a
      assert_equal expected, Post.where('id = 1').or(Post.all).to_a
    end

    def test_or_preserves_other_querying_methods
      expected = Post.where('id = 1 or id = 2 or id = 3').order('body asc').to_a
      assert_equal expected, Post.where('id = 1').order('body asc').or(:id => [2, 3]).to_a
    end

    def test_or_with_named_scope
      expected = Post.where("id = 1 or body LIKE '\%a\%'").to_a
      assert_equal expected, Post.where('id = 1').or.containing_the_letter_a
    end

  end
end