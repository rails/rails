# frozen_string_literal: true

require "test_helper"

class BroadcastChannel < ActionCable::Channel::Base
end

class TransmissionsTest < ActionCable::TestCase
  def test_assert_broadcasts
    assert_nothing_raised do
      assert_broadcasts("test", 1) do
        ActionCable.server.broadcast "test", "message"
      end
    end
  end

  def test_capture_broadcasts
    messages = capture_broadcasts("test") do
      ActionCable.server.broadcast "test", "message"
    end
    assert_equal "message", messages.first

    messages = capture_broadcasts("test") do
      ActionCable.server.broadcast "test", { message: "one" }
      ActionCable.server.broadcast "test", { message: "two" }
    end
    assert_equal 2, messages.length
    assert_equal({ "message" => "one" }, messages.first)
    assert_equal({ "message" => "two" }, messages.last)
  end

  def test_assert_broadcasts_with_no_block
    assert_nothing_raised do
      ActionCable.server.broadcast "test", "message"
      assert_broadcasts "test", 1
    end

    assert_nothing_raised do
      ActionCable.server.broadcast "test", "message 2"
      ActionCable.server.broadcast "test", "message 3"
      assert_broadcasts "test", 3
    end
  end

  def test_assert_no_broadcasts_with_no_block
    assert_nothing_raised do
      assert_no_broadcasts "test"
    end
  end

  def test_assert_no_broadcasts
    assert_nothing_raised do
      assert_no_broadcasts("test") do
        ActionCable.server.broadcast "test2", "message"
      end
    end
  end

  def test_assert_broadcasts_message_too_few_sent
    ActionCable.server.broadcast "test", "hello"
    error = assert_raises Minitest::Assertion do
      assert_broadcasts("test", 2) do
        ActionCable.server.broadcast "test", "world"
      end
    end

    assert_match(/2 .* but 1/, error.message)
  end

  def test_assert_broadcasts_message_too_many_sent
    error = assert_raises Minitest::Assertion do
      assert_broadcasts("test", 1) do
        ActionCable.server.broadcast "test", "hello"
        ActionCable.server.broadcast "test", "world"
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_no_broadcasts_failure
    error = assert_raises Minitest::Assertion do
      assert_no_broadcasts "test" do
        ActionCable.server.broadcast "test", "hello"
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end
end

class TransmittedDataTest < ActionCable::TestCase
  include ActionCable::TestHelper

  def test_assert_broadcast_on
    assert_nothing_raised do
      assert_broadcast_on("test", "message") do
        ActionCable.server.broadcast "test", "message"
      end
    end
  end

  def test_assert_broadcast_on_with_hash
    assert_nothing_raised do
      assert_broadcast_on("test", text: "hello") do
        ActionCable.server.broadcast "test", { text: "hello" }
      end
    end
  end

  def test_assert_broadcast_on_with_no_block
    assert_nothing_raised do
      ActionCable.server.broadcast "test", "hello"
      assert_broadcast_on "test", "hello"
    end

    assert_nothing_raised do
      ActionCable.server.broadcast "test", "world"
      assert_broadcast_on "test", "world"
    end
  end

  def test_assert_broadcast_on_message
    ActionCable.server.broadcast "test", "hello"
    error = assert_raises Minitest::Assertion do
      assert_broadcast_on("test", "world")
    end

    assert_match(/No messages sent/, error.message)
    assert_match(/Message\(s\) found:\nhello/, error.message)
  end

  def test_assert_broadcast_on_message_with_empty_channel
    error = assert_raises Minitest::Assertion do
      assert_broadcast_on("test", "world")
    end

    assert_match(/No messages sent/, error.message)
    assert_match(/No message found for test/, error.message)
  end
end
