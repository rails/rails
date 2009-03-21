require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module HappyPath
  
  # This has no layout and it works
  class RenderActionLolController < ActionController::Base2
    
    self.view_paths = [ActionView::FixtureTemplate::FixturePath.new({
      "happy_path/render_action_lol/hello_world.html.erb"   => "Hello world!",
      "happy_path/render_action_lol/goodbye_world.html.erb" => "Goodbye world!",
      "happy_path/sexy_time/borat.html.erb"             => "I LIKE!!!"
    })]
    
    def render_action_hello_world
      render :action => "hello_world"
    end
    
    def render_action_goodbye_world
      render :action => "goodbye_world"
    end
    
  end
  
  class SexyTimeController < ActionController::Base2
    self.view_paths = [ActionView::FixtureTemplate::FixturePath.new({
      "happy_path/render_action_lol/hello_world.html.erb"   => "Hello world!",
      "happy_path/render_action_lol/goodbye_world.html.erb" => "Goodbye world!",
      "happy_path/sexy_time/borat.html.erb"             => "I LIKE!!!"
    })]
    
    def borat
      render "borat"
    end
  end
  
  class TestRenderHelloAction < SimpleRouteCase
  
    describe "Rendering an action using :action => <String>"
  
    get "/happy_path/render_action/render_action_hello_world"
    assert_body   "Hello world!"
    assert_status 200
  
  end
  
  class TestRenderGoodbyeAction < SimpleRouteCase
    describe "Goodbye"
    
    get "/happy_path/render_action_lol/render_action_goodbye_world"
    assert_body "Goodbye world!"
    assert_status 200
  end
  
  class TestRenderBorat < SimpleRouteCase
    describe "Borat yo"
    get "/happy_path/sexy_time/borat"
    assert_body "I LIKE!!!"
    assert_status 200
  end
end