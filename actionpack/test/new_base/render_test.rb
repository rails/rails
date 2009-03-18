require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module HappyPath
  
  class RenderTextController < ActionController::Base2
    def render_hello_world_from_variable
      @person = "david"
      render :text => "hello #{@person}"
    end
    
    def render_custom_code
      render :text => "hello world", :status => 404
    end
    
    def render_with_custom_code_as_string
      render :text => "hello world", :status => "404 Not Found"
    end
    
    def render_text_with_nil
      render :text => nil
    end
    
    def render_text_with_nil_and_status
      render :text => nil, :status => 403
    end

    def render_text_with_false
      render :text => false
    end
  end
  
  class TestSimpleTextRender < SimpleRouteCase    
    describe "Rendering text from a action with default options"
    
    get "/happy_path/render_text/render_hello_world_from_variable"
    assert_body   "hello david"
    assert_status 200
  end
  
  class TestTextRenderWithStatus < SimpleRouteCase
    describe "Rendering text, while also providing a custom status code"
    
    get "/happy_path/render_text/render_custom_code"
    assert_body   "hello world"
    assert_status 404
  end
  
  class TestTextRenderWithNil < SimpleRouteCase
    describe "Rendering text with nil returns a single space character"
    
    get "/happy_path/render_text/render_text_with_nil"
    assert_body   " "
    assert_status 200
  end
  
  class TestTextRenderWithNilAndStatus < SimpleRouteCase
    describe "Rendering text with nil and custom status code returns a single space character with the status"
    
    get "/happy_path/render_text/render_text_with_nil_and_status"
    assert_body   " "
    assert_status 403
  end
  
  class TestTextRenderWithFalse < SimpleRouteCase
    describe "Rendering text with false returns the string 'false'"
    
    get "/happy_path/render_text/render_text_with_false"
    assert_body   "false"
    assert_status 200
  end
  
  class RenderTemplateController < ActionController::Base2
    
    def render_hello_world
      render :template => "test/basic"
    end

    def render_hello_world_with_forward_slash
      render :template => "/test/basic"
    end

    def render_template_in_top_directory
      render :template => 'shared'
    end

    def render_template_in_top_directory_with_slash
      render :template => '/shared'
    end
  end
  
  class TestTemplateRender < SimpleRouteCase
    describe "rendering a normal template with full path"
    
    get "/happy_path/render_template/render_hello_world"
    assert_body   "Hello from basic.html.erb"
    assert_status 200
  end
  
  class TestTemplateRenderWithForwardSlash < SimpleRouteCase
    describe "rendering a normal template with full path starting with a leading slash"
    
    get "/happy_path/render_template/render_hello_world_with_forward_slash"
    assert_body   "Hello from basic.html.erb"
    assert_status 200
  end
  
  class TestTemplateRenderInTopDirectory < SimpleRouteCase
    describe "rendering a template not in a subdirectory"
    
    get "/happy_path/render_template/render_template_in_top_directory"
    assert_body   "Elastica"
    assert_status 200
  end

  class TestTemplateRenderInTopDirectoryWithSlash < SimpleRouteCase
    describe "rendering a template not in a subdirectory with a leading slash"
    
    get "/happy_path/render_template/render_template_in_top_directory_with_slash"
    assert_body   "Elastica"
    assert_status 200
  end

  # TODO: Other language craziness
end