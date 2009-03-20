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
    
    def initialize(body, template_path, load_paths = [])
      @body = body
    end
    
    def relative_path
      "fail"
    end
    
    def filename
      "fail"
    end
    
    def method_name_without_locals
      "abc"
    end
    
    def source
      @body
    end
  end
end

OMG = {
  "happy_path/render_action/hello_world.html.erb" => "Hello world!"
}

module HappyPath
  
  # This has no layout and it works
  class RenderActionController < ActionController::Base2
    
    self.view_paths = [ActionView::FixtureTemplate::FixturePath.new(OMG)]
    
    def render_action_hello_world
      render :action => "hello_world"
    end
    
  end
  
  class TestRenderAction < SimpleRouteCase

    describe "Rendering an action using :action => <String>"

    get "/happy_path/render_action/render_action_hello_world"
    assert_body   "Hello world!"
    assert_status 200

  end
end