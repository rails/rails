require 'abstract_unit'

module Rails
  class Application
    class Path
      attr_accessor :path, :root #, :glob, :load_once, :eager
      
      def initialize(path, root = nil)
        @children = {}
        @path = path
        @root = root || self
      end
      
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
      
      def path
        @path.index('/') == 0 ? @path : File.join(@root.path, @path)
      end
      
      alias to_s path
    end
  end
end

class PathsTest < ActiveSupport::TestCase
  
  def setup
    @root = Rails::Application::Path.new("/foo/bar")
  end
  
  test "the paths object is initialized with the root path" do
    root = Rails::Application::Path.new("/fiz/baz")
    assert_equal "/fiz/baz", root.to_s
  end
  
  test "creating a root level path" do
    @root.app = "/foo/bar"
    assert_equal "/foo/bar", @root.app.to_s
  end
  
  test "relative paths are relative to the paths root" do
    @root.app = "app"
    assert_equal "/foo/bar/app", @root.app.to_s
  end
  
  test "creating a child level path" do
    @root.app        = "/foo/bar"
    @root.app.models = "/foo/bar/baz"
    assert_equal "/foo/bar/baz", @root.app.models.to_s
  end
  
  test "child level paths are relative from the root" do
    @root.app        = "/app"
    @root.app.models = "baz"
    
    assert_equal "/foo/bar/baz", @root.app.models.to_s
  end
end