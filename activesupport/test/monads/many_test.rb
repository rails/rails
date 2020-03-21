# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/monads/many"

class Monads::ManyTest < ActiveSupport::TestCase
  Post = Struct.new(:title, :comments)
  Comment = Struct.new(:body)

  def test_many_monad_values
    assert_equal posts, many_monad(posts).values
  end

  def test_try
    expected = ["REMOTE WORK", "WELCOME TO THE WEBLOG"]
    actual = []
    many_monad(posts).try do |post|
      actual << post.title.upcase
      Monads::Many.new(post)
    end

    assert_equal expected, actual
  end

  def test_try_with_empty_collection_doesnt_raise_on_block
    assert_empty many_monad([]).try { |value| values * 2 }.values
  end

  def test_many_monad_returns_flattened_collection
    expected = ["Nice post", "Awesome", "Thank you"]
    assert_equal expected, many_monad(posts).comments.body.values
  end

  def test_many_monad_raises_error_if_method_is_not_defined_on_value
    assert_raises do
      many_monad(posts).comments.created_at
    end
  end

  private
    def many_monad(values)
      Monads::Many.new(values)
    end

    def posts
      @_posts ||= [
        Post.new("Remote Work", [Comment.new("Nice post"), Comment.new("Awesome")]),
        Post.new("Welcome to the weblog", [Comment.new("Thank you")])
      ]
    end
end
