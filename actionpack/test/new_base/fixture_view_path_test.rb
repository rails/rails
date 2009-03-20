require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module ActionView #:nodoc:
  class FixtureTemplate < Template
    class FixturePath < Template::Path
      def initialize(hash)
        @hash = {}
        
        hash.each do |k, v|
          @hash[k.sub(/\.\w+$/, '')] = FixtureTemplate.new(v, k.split("/").last, self)
        end
        
        super("")
      end
      
      def find_template(path)
        @hash[path]
      end
    end
    
    def initialize(body, *args)
      @body = body
      super(*args)
    end
    
    def source
      @body
    end
  
  private
  
    def find_full_path(path, load_paths)
      return '/', path
    end
  
  end
end

OMG = {
  "happy_path/render_action/hello_world.html.erb"   => "Hello world!",
  "happy_path/render_action/goodbye_world.html.erb" => "Goodbye world!",
  "happy_path/sexy_time/borat.html.erb"             => "I LIKE!!!"
}

module HappyPath
  
  # This has no layout and it works
  class RenderActionController < ActionController::Base2
    
    self.view_paths = [ActionView::FixtureTemplate::FixturePath.new(OMG)]
    
    def render_action_hello_world
      render :action => "hello_world"
    end
    
    def render_action_goodbye_world
      render :action => "goodbye_world"
    end
    
  end
  
  class SexyTimeController < ActionController::Base2
    self.view_paths = [ActionView::FixtureTemplate::FixturePath.new(OMG)]
    
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
    
    get "/happy_path/render_action/render_action_goodbye_world"
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