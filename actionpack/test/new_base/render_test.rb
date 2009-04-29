require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module Render
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