require 'abstract_unit'

module Rails
  class Application
    module PathParent
      def method_missing(id, *args)
        name = id.to_s

        if name =~ /^(.*)=$/
          @children[$1] = Path.new(args.first, @root)
        elsif path = @children[name]
          path
        else
          super
        end
      end
    end

    class Root
      include PathParent

      attr_reader :path
      def initialize(path)
        raise unless path.is_a?(String)

        @children = {}

        # TODO: Move logic from set_root_path initializer
        @path = File.expand_path(path)
        @root = self
      end
    end

    class Path
      include PathParent

      attr_reader :path #, :glob, :load_once, :eager

      def initialize(path, root)
        @children = {}
        @root     = root
        @paths    = [path].flatten
      end

      def push(path)
        @paths.push path
      end

      alias << push

      def unshift(path)
        @paths.unshift path
      end


      def paths
        @paths.map do |path|
          path.index('/') == 0 ? path : File.join(@root.path, path)
        end
      end

      alias to_a paths
    end
  end
end

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

  test "relative paths are relative to the paths root" do
    @root.app = "app"
    assert_equal ["/foo/bar/app"], @root.app.to_a
  end

  test "creating a child level path" do
    @root.app        = "/foo/bar"
    @root.app.models = "/foo/bar/baz"
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

  test "adding multiple physical paths using #unshift" do
    @root.app = "/app"
    @root.app.unshift "/app2"
    assert_equal ["/app2", "/app"], @root.app.to_a
  end

  test "the root can only have one physical path" do
    assert_raise(RuntimeError) { Rails::Application::Root.new(["/fiz", "/biz"]) }
    assert_raise(NoMethodError) { @root.push "/biz"    }
    assert_raise(NoMethodError) { @root.unshift "/biz" }
    assert_raise(NoMethodError) { @root << "/biz"      }
  end
end