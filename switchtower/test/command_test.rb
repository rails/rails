$:.unshift File.dirname(__FILE__) + "/../lib"

require 'stringio'
require 'test/unit'
require 'switchtower/command'

class CommandTest < Test::Unit::TestCase
  class MockSession
    def open_channel
      { :closed => true, :status => 0 }
    end
  end

  class MockActor
    attr_reader :sessions

    def initialize
      @sessions = Hash.new { |h,k| h[k] = MockSession.new }
    end
  end

  def setup
    @actor = MockActor.new
  end

  def test_command_executes_on_all_servers
    command = SwitchTower::Command.new(%w(server1 server2 server3),
      "hello", nil, {}, @actor)
    assert_equal %w(server1 server2 server3), @actor.sessions.keys.sort
  end

  def test_command_with_newlines
    command = SwitchTower::Command.new(%w(server1), "hello\nworld", nil, {},
      @actor)
    assert_equal "hello\\\nworld", command.command
  end

  def test_command_with_windows_newlines
    command = SwitchTower::Command.new(%w(server1), "hello\r\nworld", nil, {},
      @actor)
    assert_equal "hello\\\nworld", command.command
  end
end
