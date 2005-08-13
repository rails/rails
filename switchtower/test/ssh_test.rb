$:.unshift File.dirname(__FILE__) + "/../lib"

require File.dirname(__FILE__) + "/utils"
require 'test/unit'
require 'switchtower/ssh'

class SSHTest < Test::Unit::TestCase
  class MockSSH
    AuthenticationFailed = Net::SSH::AuthenticationFailed

    class <<self
      attr_accessor :story
      attr_accessor :invocations
    end

    def self.start(server, opts, &block)
      @invocations << [server, opts, block]
      err = story.shift
      raise err if err
    end
  end

  def setup
    @config = MockConfiguration.new
    @config[:user] = 'demo'
    @config[:password] = 'c0c0nutfr0st1ng'
    MockSSH.story = []
    MockSSH.invocations = []
  end

  def test_publickey_auth_succeeds_default_port_no_block
    Net.const_during(:SSH, MockSSH) do
      SwitchTower::SSH.connect('demo.server.i', @config)
    end

    assert_equal 1, MockSSH.invocations.length
    assert_equal 'demo.server.i', MockSSH.invocations.first[0]
    assert_equal 22, MockSSH.invocations.first[1][:port]
    assert_equal 'demo', MockSSH.invocations.first[1][:username]
    assert_nil MockSSH.invocations.first[1][:password]
    assert_equal %w(publickey hostbased),
      MockSSH.invocations.first[1][:auth_methods]
    assert_nil MockSSH.invocations.first[2]
  end

  def test_publickey_auth_succeeds_explicit_port_no_block
    Net.const_during(:SSH, MockSSH) do
      SwitchTower::SSH.connect('demo.server.i', @config, 23)
    end

    assert_equal 1, MockSSH.invocations.length
    assert_equal 23, MockSSH.invocations.first[1][:port]
    assert_nil MockSSH.invocations.first[2]
  end

  def test_publickey_auth_succeeds_with_block
    Net.const_during(:SSH, MockSSH) do
      SwitchTower::SSH.connect('demo.server.i', @config) do |session|
      end
    end

    assert_equal 1, MockSSH.invocations.length
    assert_instance_of Proc, MockSSH.invocations.first[2]
  end

  def test_publickey_auth_fails
    MockSSH.story << Net::SSH::AuthenticationFailed

    Net.const_during(:SSH, MockSSH) do
      SwitchTower::SSH.connect('demo.server.i', @config)
    end

    assert_equal 2, MockSSH.invocations.length

    assert_nil MockSSH.invocations.first[1][:password]
    assert_equal %w(publickey hostbased),
      MockSSH.invocations.first[1][:auth_methods]

    assert_equal 'c0c0nutfr0st1ng', MockSSH.invocations.last[1][:password]
    assert_equal %w(password keyboard-interactive),
      MockSSH.invocations.last[1][:auth_methods]
  end

  def test_password_auth_fails
    MockSSH.story << Net::SSH::AuthenticationFailed
    MockSSH.story << Net::SSH::AuthenticationFailed

    Net.const_during(:SSH, MockSSH) do
      assert_raises(Net::SSH::AuthenticationFailed) do
        SwitchTower::SSH.connect('demo.server.i', @config)
      end
    end

    assert_equal 2, MockSSH.invocations.length

    assert_nil MockSSH.invocations.first[1][:password]
    assert_equal %w(publickey hostbased),
      MockSSH.invocations.first[1][:auth_methods]

    assert_equal 'c0c0nutfr0st1ng', MockSSH.invocations.last[1][:password]
    assert_equal %w(password keyboard-interactive),
      MockSSH.invocations.last[1][:auth_methods]
  end
end
