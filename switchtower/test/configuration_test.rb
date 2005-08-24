$:.unshift File.dirname(__FILE__) + "/../lib"

require 'test/unit'
require 'switchtower/configuration'
require 'flexmock'

class ConfigurationTest < Test::Unit::TestCase
  class MockActor
    attr_reader :tasks

    def initialize(config)
    end

    def define_task(*args, &block)
      (@tasks ||= []).push [args, block].flatten
    end
  end

  class MockSCM
    attr_reader   :configuration

    def initialize(config)
      @configuration = config
    end
  end

  def setup
    @config = SwitchTower::Configuration.new(MockActor)
    @config.set :scm, MockSCM
  end

  def test_version_dir_default
    assert "releases", @config.version_dir
  end

  def test_current_dir_default
    assert "current", @config.current_dir
  end

  def test_shared_dir_default
    assert "shared", @config.shared_dir
  end

  def test_set_repository
    @config.set :repository, "/foo/bar/baz"
    assert_equal "/foo/bar/baz", @config.repository
  end

  def test_set_user
    @config.set :user, "flippy"
    assert_equal "flippy", @config.user
  end

  def test_define_single_role
    @config.role :app, "somewhere.example.com"
    assert_equal 1, @config.roles[:app].length
    assert_equal "somewhere.example.com", @config.roles[:app].first.host
    assert_equal Hash.new, @config.roles[:app].first.options
  end

  def test_define_single_role_with_options
    @config.role :app, "somewhere.example.com", :primary => true
    assert_equal 1, @config.roles[:app].length
    assert_equal "somewhere.example.com", @config.roles[:app].first.host
    assert_equal({:primary => true}, @config.roles[:app].first.options)
  end

  def test_define_multi_role
    @config.role :app, "somewhere.example.com", "else.example.com"
    assert_equal 2, @config.roles[:app].length
    assert_equal "somewhere.example.com", @config.roles[:app].first.host
    assert_equal "else.example.com", @config.roles[:app].last.host
    assert_equal({}, @config.roles[:app].first.options)
    assert_equal({}, @config.roles[:app].last.options)
  end

  def test_define_multi_role_with_options
    @config.role :app, "somewhere.example.com", "else.example.com", :primary => true
    assert_equal 2, @config.roles[:app].length
    assert_equal "somewhere.example.com", @config.roles[:app].first.host
    assert_equal "else.example.com", @config.roles[:app].last.host
    assert_equal({:primary => true}, @config.roles[:app].first.options)
    assert_equal({:primary => true}, @config.roles[:app].last.options)
  end

  def test_load_string_unnamed
    @config.load :string => "set :repository, __FILE__"
    assert_equal "<eval>", @config.repository
  end

  def test_load_string_named
    @config.load :string => "set :repository, __FILE__", :name => "test.rb"
    assert_equal "test.rb", @config.repository
  end

  def test_load
    file = File.dirname(__FILE__) + "/fixtures/config.rb"
    @config.load file
    assert_equal "1/2/foo", @config.repository
    assert_equal "./#{file}.example.com", @config.gateway
    assert_equal 1, @config.roles[:web].length
  end

  def test_load_explicit_name
    file = File.dirname(__FILE__) + "/fixtures/config.rb"
    @config.load file, :name => "config"
    assert_equal "1/2/foo", @config.repository
    assert_equal "config.example.com", @config.gateway
    assert_equal 1, @config.roles[:web].length
  end

  def test_load_file_implied_name
    file = File.dirname(__FILE__) + "/fixtures/config.rb"
    @config.load :file => file
    assert_equal "1/2/foo", @config.repository
    assert_equal "./#{file}.example.com", @config.gateway
    assert_equal 1, @config.roles[:web].length
  end

  def test_load_file_explicit_name
    file = File.dirname(__FILE__) + "/fixtures/config.rb"
    @config.load :file => file, :name => "config"
    assert_equal "1/2/foo", @config.repository
    assert_equal "config.example.com", @config.gateway
    assert_equal 1, @config.roles[:web].length
  end

  def test_task_without_options
    block = Proc.new { }
    @config.task :hello, &block
    assert_equal 1, @config.actor.tasks.length
    assert_equal :hello, @config.actor.tasks[0][0]
    assert_equal({}, @config.actor.tasks[0][1])
    assert_equal block, @config.actor.tasks[0][2]
  end

  def test_task_with_options
    block = Proc.new { }
    @config.task :hello, :roles => :app, &block
    assert_equal 1, @config.actor.tasks.length
    assert_equal :hello, @config.actor.tasks[0][0]
    assert_equal({:roles => :app}, @config.actor.tasks[0][1])
    assert_equal block, @config.actor.tasks[0][2]
  end

  def test_source
    @config.set :repository, "/foo/bar/baz"
    assert_equal "/foo/bar/baz", @config.source.configuration.repository
  end

  def test_releases_path_default
    @config.set :deploy_to, "/start/of/path"
    assert_equal "/start/of/path/releases", @config.releases_path
  end

  def test_releases_path_custom
    @config.set :deploy_to, "/start/of/path"
    @config.set :version_dir, "right/here"
    assert_equal "/start/of/path/right/here", @config.releases_path
  end

  def test_current_path_default
    @config.set :deploy_to, "/start/of/path"
    assert_equal "/start/of/path/current", @config.current_path
  end

  def test_current_path_custom
    @config.set :deploy_to, "/start/of/path"
    @config.set :current_dir, "right/here"
    assert_equal "/start/of/path/right/here", @config.current_path
  end

  def test_shared_path_default
    @config.set :deploy_to, "/start/of/path"
    assert_equal "/start/of/path/shared", @config.shared_path
  end

  def test_shared_path_custom
    @config.set :deploy_to, "/start/of/path"
    @config.set :shared_dir, "right/here"
    assert_equal "/start/of/path/right/here", @config.shared_path
  end

  def test_release_path_implicit
    @config.set :deploy_to, "/start/of/path"
    assert_equal "/start/of/path/releases/#{@config.now.strftime("%Y%m%d%H%M%S")}", @config.release_path
  end

  def test_release_path_explicit
    @config.set :deploy_to, "/start/of/path"
    assert_equal "/start/of/path/releases/silly", @config.release_path("silly")
  end

  def test_task_description
    block = Proc.new { }
    @config.desc "A sample task"
    @config.task :hello, &block
    assert_equal "A sample task", @config.actor.tasks[0][1][:desc]
  end

  def test_set_scm_to_darcs
    @config.set :scm, :darcs
    assert_equal "SwitchTower::SCM::Darcs", @config.source.class.name
  end

  def test_set_scm_to_subversion
    @config.set :scm, :subversion
    assert_equal "SwitchTower::SCM::Subversion", @config.source.class.name
  end
end
