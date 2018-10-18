# frozen_string_literal: true

require "test_helper"

class TestTestChannel < ActionCable::Channel::Base
end

class NonInferrableExplicitClassChannelTest < ActionCable::Channel::TestCase
  tests TestTestChannel

  def test_set_channel_class_manual
    assert_equal TestTestChannel, self.class.channel_class
  end
end

class NonInferrableSymbolNameChannelTest < ActionCable::Channel::TestCase
  tests :test_test_channel

  def test_set_channel_class_manual_using_symbol
    assert_equal TestTestChannel, self.class.channel_class
  end
end

class NonInferrableStringNameChannelTest < ActionCable::Channel::TestCase
  tests "test_test_channel"

  def test_set_channel_class_manual_using_string
    assert_equal TestTestChannel, self.class.channel_class
  end
end

class SubscriptionsTestChannel < ActionCable::Channel::Base
end

class SubscriptionsTestChannelTest < ActionCable::Channel::TestCase
  def setup
    stub_connection
  end

  def test_no_subscribe
    assert_nil subscription
  end

  def test_subscribe
    subscribe

    assert subscription.confirmed?
    assert_not subscription.rejected?
    assert_equal 1, connection.transmissions.size
    assert_equal ActionCable::INTERNAL[:message_types][:confirmation],
                 connection.transmissions.last["type"]
  end
end

class StubConnectionTest < ActionCable::Channel::TestCase
  tests SubscriptionsTestChannel

  def test_connection_identifiers
    stub_connection username: "John", admin: true

    subscribe

    assert_equal "John", subscription.username
    assert subscription.admin
  end
end

class RejectionTestChannel < ActionCable::Channel::Base
  def subscribed
    reject
  end
end

class RejectionTestChannelTest < ActionCable::Channel::TestCase
  def test_rejection
    subscribe

    assert_not subscription.confirmed?
    assert subscription.rejected?
    assert_equal 1, connection.transmissions.size
    assert_equal ActionCable::INTERNAL[:message_types][:rejection],
                 connection.transmissions.last["type"]
  end
end

class StreamsTestChannel < ActionCable::Channel::Base
  def subscribed
    stream_from "test_#{params[:id] || 0}"
  end
end

class StreamsTestChannelTest < ActionCable::Channel::TestCase
  def test_stream_without_params
    subscribe

    assert_equal "test_0", streams.last
  end

  def test_stream_with_params
    subscribe id: 42

    assert_equal "test_42", streams.last
  end
end

class PerformTestChannel < ActionCable::Channel::Base
  def echo(data)
    data.delete("action")
    transmit data
  end

  def ping
    transmit type: "pong"
  end
end

class PerformTestChannelTest < ActionCable::Channel::TestCase
  def setup
    stub_connection user_id: 2016
    subscribe id: 5
  end

  def test_perform_with_params
    perform :echo, text: "You are man!"

    assert_equal({ "text" => "You are man!" }, transmissions.last)
  end

  def test_perform_and_transmit
    perform :ping

    assert_equal "pong", transmissions.last["type"]
  end
end

class PerformUnsubscribedTestChannelTest < ActionCable::Channel::TestCase
  tests PerformTestChannel

  def test_perform_when_unsubscribed
    assert_raises do
      perform :echo
    end
  end
end

class BroadcastsTestChannel < ActionCable::Channel::Base
  def broadcast(data)
    ActionCable.server.broadcast(
      "broadcast_#{params[:id]}",
      text: data["message"], user_id: user_id
    )
  end

  def broadcast_to_user(data)
    user = User.new user_id

    self.class.broadcast_to user, text: data["message"]
  end
end

class BroadcastsTestChannelTest < ActionCable::Channel::TestCase
  def setup
    stub_connection user_id: 2017
    subscribe id: 5
  end

  def test_broadcast_matchers_included
    assert_broadcast_on("broadcast_5", user_id: 2017, text: "SOS") do
      perform :broadcast, message: "SOS"
    end
  end

  def test_broadcast_to_object
    user = User.new(2017)

    assert_broadcasts(user, 1) do
      perform :broadcast_to_user, text: "SOS"
    end
  end

  def test_broadcast_to_object_with_data
    user = User.new(2017)

    assert_broadcast_on(user, text: "SOS") do
      perform :broadcast_to_user, message: "SOS"
    end
  end
end
