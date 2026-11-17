# frozen_string_literal: true

require "cases/helper"
require "active_model/nested_error"
require "models/topic"
require "models/reply"

class NestedErrorTest < ActiveModel::TestCase
  def test_initialize
    topic = Topic.new
    inner_error = ActiveModel::Error.new(topic, :title, :not_enough, count: 2)
    reply = Reply.new
    error = ActiveModel::NestedError.new(reply, inner_error)

    assert_equal reply, error.base
    assert_equal inner_error.attribute, error.attribute
    assert_equal inner_error.type, error.type
    assert_equal(inner_error.options, error.options)
  end

  test "initialize with overriding attribute and type" do
    topic = Topic.new
    inner_error = ActiveModel::Error.new(topic, :title, :not_enough, count: 2)
    reply = Reply.new
    error = ActiveModel::NestedError.new(reply, inner_error, attribute: :parent, type: :foo)

    assert_equal reply, error.base
    assert_equal :parent, error.attribute
    assert_equal :foo, error.type
    assert_equal(inner_error.options, error.options)
  end

  test "inner_error returns the original error" do
    topic = Topic.new
    inner_error = ActiveModel::Error.new(topic, :title, :invalid)
    reply = Reply.new
    error = ActiveModel::NestedError.new(reply, inner_error)

    assert_same inner_error, error.inner_error
  end

  test "raw_type is taken from the inner error" do
    topic = Topic.new
    inner_error = ActiveModel::Error.new(topic, :title, :not_enough, count: 2)
    reply = Reply.new
    error = ActiveModel::NestedError.new(reply, inner_error)

    assert_equal inner_error.raw_type, error.raw_type
  end

  test "options are taken from the inner error" do
    topic = Topic.new
    inner_error = ActiveModel::Error.new(topic, :title, :not_enough, count: 2)
    reply = Reply.new
    error = ActiveModel::NestedError.new(reply, inner_error, attribute: :parent)

    assert_equal inner_error.options, error.options
  end

  def test_message
    topic = Topic.new(author_name: "Bruce")
    inner_error = ActiveModel::Error.new(topic, :title, :not_enough, message: Proc.new { |model, options|
      "not good enough for #{model.author_name}"
    })
    reply = Reply.new(author_name: "Mark")
    error = ActiveModel::NestedError.new(reply, inner_error)

    assert_equal "not good enough for Bruce", error.message
  end

  def test_full_message
    topic = Topic.new(author_name: "Bruce")
    inner_error = ActiveModel::Error.new(topic, :title, :not_enough, message: Proc.new { |model, options|
      "not good enough for #{model.author_name}"
    })
    reply = Reply.new(author_name: "Mark")
    error = ActiveModel::NestedError.new(reply, inner_error)

    assert_equal "Title not good enough for Bruce", error.full_message
  end
end
