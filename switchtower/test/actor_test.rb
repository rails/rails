$:.unshift File.dirname(__FILE__) + "/../lib"

require 'stringio'
require 'test/unit'
require 'switchtower/actor'
require 'switchtower/logger'

class ActorTest < Test::Unit::TestCase

  class TestingConnectionFactory
    def initialize(config)
    end

    def connect_to(server)
      server
    end
  end

  class GatewayConnectionFactory
    def connect_to(server)
      server
    end
  end

  class TestingCommand
    def self.invoked!
      @invoked = true
    end

    def self.invoked?
      @invoked
    end

    def self.reset!
      @invoked = nil
    end

    def initialize(*args)
    end

    def process!
      self.class.invoked!
    end
  end

  class TestActor < SwitchTower::Actor
    attr_reader :factory

    self.connection_factory = TestingConnectionFactory
    self.command_factory = TestingCommand

    def establish_gateway
      GatewayConnectionFactory.new
    end
  end

  class MockConfiguration
    Role = Struct.new(:host, :options)

    attr_accessor :gateway, :pretend

    def delegated_method
      "result of method"
    end

    ROLES = { :db  => [ Role.new("01.example.com", :primary => true),
                        Role.new("02.example.com", {}),
                        Role.new("all.example.com", {})],
              :web => [ Role.new("03.example.com", {}),
                        Role.new("04.example.com", {}),
                        Role.new("all.example.com", {})],
              :app => [ Role.new("05.example.com", {}),
                        Role.new("06.example.com", {}),
                        Role.new("07.example.com", {}),
                        Role.new("all.example.com", {})] }

    def roles
      ROLES
    end

    def logger
      @logger ||= SwitchTower::Logger.new(:output => StringIO.new)
    end
  end

  def setup
    TestingCommand.reset!
    @actor = TestActor.new(MockConfiguration.new)
  end

  def test_define_task_creates_method
    @actor.define_task :hello do
      "result"
    end
    assert @actor.respond_to?(:hello)
    assert_equal "result", @actor.hello
  end

  def test_define_task_with_successful_transaction
    class << @actor
      attr_reader :rolled_back
      attr_reader :history
    end

    @actor.define_task :hello do
      (@history ||= []) << :hello
      on_rollback { @rolled_back = true }
      "hello"
    end

    @actor.define_task :goodbye do
      (@history ||= []) << :goodbye
      transaction do
        hello
      end
      "goodbye"
    end

    assert_nothing_raised { @actor.goodbye }
    assert !@actor.rolled_back
    assert_equal [:goodbye, :hello], @actor.history
  end

  def test_define_task_with_failed_transaction
    class << @actor
      attr_reader :rolled_back
      attr_reader :history
    end

    @actor.define_task :hello do
      (@history ||= []) << :hello
      on_rollback { @rolled_back = true }
      "hello"
    end

    @actor.define_task :goodbye do
      (@history ||= []) << :goodbye
      transaction do
        hello
        raise "ouch"
      end
      "goodbye"
    end

    assert_raise(RuntimeError) do
      @actor.goodbye
    end

    assert @actor.rolled_back
    assert_equal [:goodbye, :hello], @actor.history
  end

  def test_delegates_to_configuration
    @actor.define_task :hello do
      delegated_method
    end
    assert_equal "result of method", @actor.hello
  end

  def test_task_servers_with_duplicates
    @actor.define_task :foo do
      run "do this"
    end

    assert_equal %w(01.example.com 02.example.com 03.example.com 04.example.com 05.example.com 06.example.com 07.example.com all.example.com), @actor.tasks[:foo].servers(@actor.configuration).sort
  end

  def test_run_in_task_without_explicit_roles_selects_all_roles
    @actor.define_task :foo do
      run "do this"
    end

    @actor.foo
    assert_equal %w(01.example.com 02.example.com 03.example.com 04.example.com 05.example.com 06.example.com 07.example.com all.example.com), @actor.sessions.keys.sort
  end

  def test_run_in_task_with_single_role_selects_that_role
    @actor.define_task :foo, :roles => :db do
      run "do this"
    end

    @actor.foo
    assert_equal %w(01.example.com 02.example.com all.example.com), @actor.sessions.keys.sort
  end

  def test_run_in_task_with_multiple_roles_selects_those_roles
    @actor.define_task :foo, :roles => [:db, :web] do
      run "do this"
    end

    @actor.foo
    assert_equal %w(01.example.com 02.example.com 03.example.com 04.example.com all.example.com), @actor.sessions.keys.sort
  end

  def test_run_in_task_with_only_restricts_selected_roles
    @actor.define_task :foo, :roles => :db, :only => { :primary => true } do
      run "do this"
    end

    @actor.foo
    assert_equal %w(01.example.com), @actor.sessions.keys.sort
  end

  def test_establish_connection_uses_gateway_if_specified
    @actor.configuration.gateway = "10.example.com"
    @actor.define_task :foo, :roles => :db do
      run "do this"
    end

    @actor.foo
    assert_instance_of GatewayConnectionFactory, @actor.factory
  end

  def test_run_when_not_pretend
    @actor.define_task :foo do
      run "do this"
    end

    @actor.configuration.pretend = false
    @actor.foo
    assert TestingCommand.invoked?
  end

  def test_run_when_pretend
    @actor.define_task :foo do
      run "do this"
    end

    @actor.configuration.pretend = true
    @actor.foo
    assert !TestingCommand.invoked?
  end

  def test_task_before_hook
    history = []
    @actor.define_task :foo do
      history << "foo"
    end

    @actor.define_task :before_foo do
      history << "before_foo"
    end

    @actor.foo
    assert_equal %w(before_foo foo), history
  end

  def test_task_after_hook
    history = []
    @actor.define_task :foo do
      history << "foo"
    end

    @actor.define_task :after_foo do
      history << "after_foo"
    end

    @actor.foo
    assert_equal %w(foo after_foo), history
  end
end
