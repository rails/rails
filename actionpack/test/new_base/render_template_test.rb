require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module HappyPath
  
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

end