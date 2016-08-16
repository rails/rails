require "abstract_unit"
require "rails/paths"
require "minitest/mock"

class PathsTest < ActiveSupport::TestCase
  def setup
    @root = Rails::Paths::Root.new("/foo/bar")
  end

  test "the paths object is initialized with the root path" do
    root = Rails::Paths::Root.new("/fiz/baz")
    assert_equal "/fiz/baz", root.path
  end

  test "the paths object can be initialized with nil" do
    assert_nothing_raised do
      Rails::Paths::Root.new(nil)
    end
  end

  test "a paths object initialized with nil can be updated" do
    root = Rails::Paths::Root.new(nil)
    root.add "app"
    root.path = "/root"
    assert_equal ["app"], root["app"].to_ary
    assert_equal ["/root/app"], root["app"].to_a
  end

  test "creating a root level path" do
    @root.add "app"
    assert_equal ["/foo/bar/app"], @root["app"].to_a
  end

  test "creating a root level path with options" do
    @root.add "app", with: "/foo/bar"
    assert_equal ["/foo/bar"], @root["app"].to_a
  end

  test "raises exception if root path never set" do
    root = Rails::Paths::Root.new(nil)
    root.add "app"
    assert_raises RuntimeError do
      root["app"].to_a
    end
  end

  test "creating a child level path" do
    @root.add "app"
    @root.add "app/models"
    assert_equal ["/foo/bar/app/models"], @root["app/models"].to_a
  end

  test "creating a child level path with option" do
    @root.add "app"
    @root.add "app/models", with: "/foo/bar/baz"
    assert_equal ["/foo/bar/baz"], @root["app/models"].to_a
  end

  test "child level paths are relative from the root" do
    @root.add "app"
    @root.add "app/models", with: "baz"
    assert_equal ["/foo/bar/baz"], @root["app/models"].to_a
  end

  test "absolute current path" do
    @root.add "config"
    @root.add "config/locales"

    assert_equal "/foo/bar/config/locales", @root["config/locales"].absolute_current
  end

  test "adding multiple physical paths as an array" do
    @root.add "app", with: ["/app", "/app2"]
    assert_equal ["/app", "/app2"], @root["app"].to_a
  end

  test "adding multiple physical paths using #push" do
    @root.add "app"
    @root["app"].push "app2"
    assert_equal ["/foo/bar/app", "/foo/bar/app2"], @root["app"].to_a
  end

  test "adding multiple physical paths using <<" do
    @root.add "app"
    @root["app"] << "app2"
    assert_equal ["/foo/bar/app", "/foo/bar/app2"], @root["app"].to_a
  end

  test "adding multiple physical paths using concat" do
    @root.add "app"
    @root["app"].concat ["app2", "/app3"]
    assert_equal ["/foo/bar/app", "/foo/bar/app2", "/app3"], @root["app"].to_a
  end

  test "adding multiple physical paths using #unshift" do
    @root.add "app"
    @root["app"].unshift "app2"
    assert_equal ["/foo/bar/app2", "/foo/bar/app"], @root["app"].to_a
  end

  test "it is possible to add a path that should be autoloaded only once" do
    File.stub(:exist?, true) do
      @root.add "app", with: "/app"
      @root["app"].autoload_once!
      assert @root["app"].autoload_once?
      assert @root.autoload_once.include?(@root["app"].expanded.first)
    end
  end

  test "it is possible to remove a path that should be autoloaded only once" do
    @root["app"] = "/app"
    @root["app"].autoload_once!
    assert @root["app"].autoload_once?

    @root["app"].skip_autoload_once!
    assert !@root["app"].autoload_once?
    assert !@root.autoload_once.include?(@root["app"].expanded.first)
  end

  test "it is possible to add a path without assignment and specify it should be loaded only once" do
    File.stub(:exist?, true) do
      @root.add "app", with: "/app", autoload_once: true
      assert @root["app"].autoload_once?
      assert @root.autoload_once.include?("/app")
    end
  end

  test "it is possible to add multiple paths without assignment and specify it should be loaded only once" do
    File.stub(:exist?, true) do
      @root.add "app", with: ["/app", "/app2"], autoload_once: true
      assert @root["app"].autoload_once?
      assert @root.autoload_once.include?("/app")
      assert @root.autoload_once.include?("/app2")
    end
  end

  test "making a path autoload_once more than once only includes it once in @root.load_once" do
    File.stub(:exist?, true) do
      @root["app"] = "/app"
      @root["app"].autoload_once!
      @root["app"].autoload_once!
      assert_equal 1, @root.autoload_once.select { |p| p == @root["app"].expanded.first }.size
    end
  end

  test "paths added to a load_once path should be added to the autoload_once collection" do
    File.stub(:exist?, true) do
      @root["app"] = "/app"
      @root["app"].autoload_once!
      @root["app"] << "/app2"
      assert_equal 2, @root.autoload_once.size
    end
  end

  test "it is possible to mark a path as eager loaded" do
    File.stub(:exist?, true) do
      @root["app"] = "/app"
      @root["app"].eager_load!
      assert @root["app"].eager_load?
      assert @root.eager_load.include?(@root["app"].to_a.first)
    end
  end

  test "it is possible to skip a path from eager loading" do
    @root["app"] = "/app"
    @root["app"].eager_load!
    assert @root["app"].eager_load?

    @root["app"].skip_eager_load!
    assert !@root["app"].eager_load?
    assert !@root.eager_load.include?(@root["app"].to_a.first)
  end

  test "it is possible to add a path without assignment and mark it as eager" do
    File.stub(:exist?, true) do
      @root.add "app", with: "/app", eager_load: true
      assert @root["app"].eager_load?
      assert @root.eager_load.include?("/app")
    end
  end

  test "it is possible to add multiple paths without assignment and mark them as eager" do
    File.stub(:exist?, true) do
      @root.add "app", with: ["/app", "/app2"], eager_load: true
      assert @root["app"].eager_load?
      assert @root.eager_load.include?("/app")
      assert @root.eager_load.include?("/app2")
    end
  end

  test "it is possible to create a path without assignment and mark it both as eager and load once" do
    File.stub(:exist?, true) do
      @root.add "app", with: "/app", eager_load: true, autoload_once: true
      assert @root["app"].eager_load?
      assert @root["app"].autoload_once?
      assert @root.eager_load.include?("/app")
      assert @root.autoload_once.include?("/app")
    end
  end

  test "making a path eager more than once only includes it once in @root.eager_paths" do
    File.stub(:exist?, true) do
      @root["app"] = "/app"
      @root["app"].eager_load!
      @root["app"].eager_load!
      assert_equal 1, @root.eager_load.select { |p| p == @root["app"].expanded.first }.size
    end
  end

  test "paths added to an eager_load path should be added to the eager_load collection" do
    File.stub(:exist?, true) do
      @root["app"] = "/app"
      @root["app"].eager_load!
      @root["app"] << "/app2"
      assert_equal 2, @root.eager_load.size
    end
  end

  test "it should be possible to add a path's default glob" do
    @root["app"] = "/app"
    @root["app"].glob = "*.rb"
    assert_equal "*.rb", @root["app"].glob
  end

  test "it should be possible to get extensions by glob" do
    @root["app"] = "/app"
    @root["app"].glob = "*.{rb,yml}"
    assert_equal ["rb", "yml"], @root["app"].extensions
  end

  test "it should be possible to override a path's default glob without assignment" do
    @root.add "app", with: "/app", glob: "*.rb"
    assert_equal "*.rb", @root["app"].glob
  end

  test "it should be possible to replace a path and persist the original paths glob" do
    @root.add "app", glob: "*.rb"
    @root["app"] = "app2"
    assert_equal ["/foo/bar/app2"], @root["app"].to_a
    assert_equal "*.rb", @root["app"].glob
  end

  test "a path can be added to the load path" do
    File.stub(:exist?, true) do
      @root["app"] = "app"
      @root["app"].load_path!
      @root["app/models"] = "app/models"
      assert_equal ["/foo/bar/app"], @root.load_paths
    end
  end

  test "a path can be added to the load path on creation" do
    File.stub(:exist?, true) do
      @root.add "app", with: "/app", load_path: true
      assert @root["app"].load_path?
      assert_equal ["/app"], @root.load_paths
    end
  end

  test "a path can be marked as autoload path" do
    File.stub(:exist?, true) do
      @root["app"] = "app"
      @root["app"].autoload!
      @root["app/models"] = "app/models"
      assert_equal ["/foo/bar/app"], @root.autoload_paths
    end
  end

  test "a path can be marked as autoload on creation" do
    File.stub(:exist?, true) do
      @root.add "app", with: "/app", autoload: true
      assert @root["app"].autoload?
      assert_equal ["/app"], @root.autoload_paths
    end
  end
end
