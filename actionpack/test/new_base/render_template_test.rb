require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module HappyPath
  
  class RenderTemplateWithoutLayoutController < ActionController::Base2
    
    self.view_paths = [ActionView::FixtureTemplate::FixturePath.new(
      "test/basic.html.erb" => "Hello from basic.html.erb",
      "shared.html.erb"     => "Elastica"
    )]
    
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
  
  class TestTemplateRenderWithoutLayout < SimpleRouteCase
    describe "rendering a normal template with full path without layout"
    
    get "/happy_path/render_template_without_layout/render_hello_world"
    assert_body   "Hello from basic.html.erb"
    assert_status 200
  end
  
  class TestTemplateRenderWithForwardSlash < SimpleRouteCase
    describe "rendering a normal template with full path starting with a leading slash"
    
    get "/happy_path/render_template_without_layout/render_hello_world_with_forward_slash"
    assert_body   "Hello from basic.html.erb"
    assert_status 200
  end
  
  class TestTemplateRenderInTopDirectory < SimpleRouteCase
    describe "rendering a template not in a subdirectory"
    
    get "/happy_path/render_template_without_layout/render_template_in_top_directory"
    assert_body   "Elastica"
    assert_status 200
  end

  class TestTemplateRenderInTopDirectoryWithSlash < SimpleRouteCase
    describe "rendering a template not in a subdirectory with a leading slash"
    
    get "/happy_path/render_template_without_layout/render_template_in_top_directory_with_slash"
    assert_body   "Elastica"
    assert_status 200
  end
    
  class RenderTemplateWithLayoutController < ::ApplicationController
    
    self.view_paths = [ActionView::FixtureTemplate::FixturePath.new(
      "test/basic.html.erb"          => "Hello from basic.html.erb",
      "shared.html.erb"              => "Elastica",
      "layouts/application.html.erb" => "<%= yield %>, I'm here!",
      "layouts/greetings.html.erb"   => "<%= yield %>, I wish thee well."
    )]
    
    def render_hello_world
      render :template => "test/basic"
    end
    
    def render_hello_world_with_layout
      render :template => "test/basic", :layout => true
    end
    
    def render_hello_world_with_layout_false
      render :template => "test/basic", :layout => false
    end
    
    def render_hello_world_with_layout_nil
      render :template => "test/basic", :layout => nil
    end
    
    def render_hello_world_with_custom_layout
      render :template => "test/basic", :layout => "greetings"
    end
  end
  
  class TestTemplateRenderWithLayout < SimpleRouteCase
    describe "rendering a normal template with full path with layout"
    
    get "/happy_path/render_template_with_layout/render_hello_world"
    assert_body   "Hello from basic.html.erb, I'm here!"
    assert_status 200
  end
  
  class TestTemplateRenderWithLayoutTrue < SimpleRouteCase
    describe "rendering a normal template with full path with layout => :true"
    
    get "/happy_path/render_template_with_layout/render_hello_world_with_layout"
    assert_body   "Hello from basic.html.erb, I'm here!"
    assert_status 200
  end
  
  class TestTemplateRenderWithLayoutFalse < SimpleRouteCase
    describe "rendering a normal template with full path with layout => :false"
    
    get "/happy_path/render_template_with_layout/render_hello_world_with_layout_false"
    assert_body   "Hello from basic.html.erb"
    assert_status 200
  end
  
  class TestTemplateRenderWithLayoutNil < SimpleRouteCase
    describe "rendering a normal template with full path with layout => :nil"
    
    get "/happy_path/render_template_with_layout/render_hello_world_with_layout_nil"
    assert_body   "Hello from basic.html.erb"
    assert_status 200
  end
  
  class TestTemplateRenderWithCustomLayout < SimpleRouteCase
    describe "rendering a normal template with full path with layout => 'greetings'"
    
    get "/happy_path/render_template_with_layout/render_hello_world_with_custom_layout"
    assert_body   "Hello from basic.html.erb, I wish thee well."
    assert_status 200
  end
  
  

end