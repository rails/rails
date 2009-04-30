require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module Render
  class BlankRenderController < ActionController::Base2
    self.view_paths = [ActionView::Template::FixturePath.new(
      "render/blank_render/index.html.erb" => "Hello world!"
    )]
    
    def index
      render
    end
  end
  
  class TestBlankRender < SimpleRouteCase
    describe "Render with blank"

    get "/render/blank_render"
    assert_body "Hello world!"
    assert_status 200
  end  
  
  class DoubleRenderController < ActionController::Base2
    def index
      render :text => "hello"
      render :text => "world"
    end
  end
  
  class TestBasic < SimpleRouteCase
    describe "Rendering more than once"
    
    test "raises an exception" do
      assert_raises(AbstractController::DoubleRenderError) do
        get "/render/double_render"
      end
    end
  end
end