require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module RenderPartial
  
  class BasicController < ActionController::Base
    
    self.view_paths = [ActionView::FixtureResolver.new(
      "render_partial/basic/_basic.html.erb"    => "OMG!",
      "render_partial/basic/basic.html.erb"      => "<%= @test_unchanged = 'goodbye' %><%= render :partial => 'basic' %><%= @test_unchanged %>"
    )]
    
    def changing
      @test_unchanged = 'hello'
      render :action => "basic"
    end    
  end
  
  class TestPartial < SimpleRouteCase
    testing BasicController
    
    test "rendering a partial in ActionView doesn't pull the ivars again from the controller" do
      get :changing
      assert_response("goodbyeOMG!goodbye")
    end
  end
  
end