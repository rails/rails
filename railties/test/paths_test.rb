require 'abstract_unit'
require 'rails/paths'

class PathsTest < ActiveSupport::TestCase

  def setup
    @root = Rails::Application::Root.new("/foo/bar")
  end

  test "the paths object is initialized with the root path" do
    root = Rails::Application::Root.new("/fiz/baz")
    assert_equal "/fiz/baz", root.path
  end

  test "creating a root level path" do
    @root.app = "/foo/bar"
    assert_equal ["/foo/bar"], @root.app.to_a
  end

  test "creating a root level path without assignment" do
    @root.app "/foo/bar"
    assert_equal ["/foo/bar"], @root.app.to_a
  end

  test "trying to access a path that does not exist raises NoMethodError" do
    assert_raises(NoMethodError) { @root.app }
  end

  test "relative paths are relative to the paths root" do
    @root.app = "app"
    assert_equal ["/foo/bar/app"], @root.app.to_a
  end

  test "relative paths are relative to the paths root without assignment" do
    @root.app "app"
    assert_equal ["/foo/bar/app"], @root.app.to_a
  end

  test "creating a child level path" do
    @root.app        = "/foo/bar"
    @root.app.models = "/foo/bar/baz"
    assert_equal ["/foo/bar/baz"], @root.app.models.to_a
  end

  test "creating a child level path without assignment" do
    @root.app        = "/foo/bar"
    @root.app.models   "/foo/bar/baz"
    assert_equal ["/foo/bar/baz"], @root.app.models.to_a
  end

  test "child level paths are relative from the root" do
    @root.app        = "/app"
    @root.app.models = "baz"

    assert_equal ["/foo/bar/baz"], @root.app.models.to_a
  end

  test "adding multiple physical paths as an array" do
    @root.app = ["/app", "/app2"]
    assert_equal ["/app", "/app2"], @root.app.to_a
  end

  test "adding multiple physical paths as an array without assignment" do
    @root.app "/app", "/app2"
    assert_equal ["/app", "/app2"], @root.app.to_a
  end

  test "adding multiple physical paths using #push" do
    @root.app = "/app"
    @root.app.push "/app2"
    assert_equal ["/app", "/app2"], @root.app.to_a
  end

  test "adding multiple physical paths using <<" do
    @root.app = "/app"
    @root.app << "/app2"
    assert_equal ["/app", "/app2"], @root.app.to_a
  end

  test "adding multiple physical paths using concat" do
    @root.app = "/app"
    @root.app.concat ["/app2", "/app3"]
    assert_equal ["/app", "/app2", "/app3"], @root.app.to_a
  end

  test "adding multiple physical paths using #unshift" do
    @root.app = "/app"
    @root.app.unshift "/app2"
    assert_equal ["/app2", "/app"], @root.app.to_a
  end

  test "the root can only have one physical path" do
    assert_raise(RuntimeError) { Rails::Application::Root.new(["/fiz", "/biz"]) }
    assert_raise(RuntimeError) { @root.push "/biz"    }
    assert_raise(RuntimeError) { @root.unshift "/biz" }
    assert_raise(RuntimeError) { @root.concat ["/biz"]}
    assert_raise(RuntimeError) { @root << "/biz"      }
  end

  test "it is possible to add a path that should be loaded only once" do
    @root.app = "/app"
    @root.app.load_once!
    assert @root.app.load_once?
    assert @root.load_once.include?(@root.app.paths.first)
  end

  test "it is possible to add a path without assignment and specify it should be loaded only once" do
    @root.app "/app", :load_once => true
    assert @root.app.load_once?
    assert @root.load_once.include?("/app")
  end

  test "it is possible to add multiple paths without assignment and specify it should be loaded only once" do
    @root.app "/app", "/app2", :load_once => true
    assert @root.app.load_once?
    assert @root.load_once.include?("/app")
    assert @root.load_once.include?("/app2")
  end

  test "making a path load_once more than once only includes it once in @root.load_once" do
    @root.app = "/app"
    @root.app.load_once!
    @root.app.load_once!
    assert_equal 1, @root.load_once.select {|p| p == @root.app.paths.first }.size
  end

  test "paths added to a load_once path should be added to the load_once collection" do
    @root.app = "/app"
    @root.app.load_once!
    @root.app << "/app2"
    assert_equal 2, @root.load_once.size
  end

  test "it is possible to mark a path as eager" do
    @root.app = "/app"
    @root.app.eager_load!
    assert @root.app.eager_load?
    assert @root.eager_load.include?(@root.app.paths.first)
  end

  test "it is possible to add a path without assignment and mark it as eager" do
    @root.app "/app", :eager_load => true
    assert @root.app.eager_load?
    assert @root.eager_load.include?("/app")
  end

  test "it is possible to add multiple paths without assignment and mark them as eager" do
    @root.app "/app", "/app2", :eager_load => true
    assert @root.app.eager_load?
    assert @root.eager_load.include?("/app")
    assert @root.eager_load.include?("/app2")
  end

  test "it is possible to create a path without assignment and mark it both as eager and load once" do
    @root.app "/app", :eager_load => true, :load_once => true
    assert @root.app.eager_load?
    assert @root.app.load_once?
    assert @root.eager_load.include?("/app")
    assert @root.load_once.include?("/app")
  end

  test "making a path eager more than once only includes it once in @root.eager_paths" do
    @root.app = "/app"
    @root.app.eager_load!
    @root.app.eager_load!
    assert_equal 1, @root.eager_load.select {|p| p == @root.app.paths.first }.size
  end

  test "paths added to a eager_load path should be added to the eager_load collection" do
    @root.app = "/app"
    @root.app.eager_load!
    @root.app << "/app2"
    assert_equal 2, @root.eager_load.size
  end

  test "a path should have a glob that defaults to **/*.rb" do
    @root.app = "/app"
    assert_equal "**/*.rb", @root.app.glob
  end

  test "it should be possible to override a path's default glob" do
    @root.app = "/app"
    @root.app.glob = "*.rb"
    assert_equal "*.rb", @root.app.glob
  end

  test "it should be possible to override a path's default glob without assignment" do
    @root.app "/app", :glob => "*.rb"
    assert_equal "*.rb", @root.app.glob
  end

  test "a path can be added to the load path" do
    @root.app = "app"
    @root.app.load_path!
    @root.app.models = "app/models"
    assert_equal ["/foo/bar/app"], @root.load_paths
  end

  test "a path can be added to the load path on creation" do
    @root.app "/app", :load_path => true
    assert @root.app.load_path?
    assert_equal ["/app"], @root.load_paths
  end

  test "adding a path to the eager paths also adds it to the load path" do
    @root.app = "app"
    @root.app.eager_load!
    assert_equal ["/foo/bar/app"], @root.load_paths
  end
end