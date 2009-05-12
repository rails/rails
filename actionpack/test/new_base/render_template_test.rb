require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module RenderTemplate
  class WithoutLayoutController < ActionController::Base
    
    self.view_paths = [ActionView::Template::FixturePath.new(
      "test/basic.html.erb" => "Hello from basic.html.erb",
      "shared.html.erb"     => "Elastica",
      "locals.html.erb"     => "The secret is <%= secret %>"
    )]
    
    def index
      render :template => "test/basic"
    end

    def in_top_directory
      render :template => 'shared'
    end

    def in_top_directory_with_slash
      render :template => '/shared'
    end
    
    def with_locals
      render :template => "locals", :locals => { :secret => 'area51' }
    end
  end
  
  class TestWithoutLayout < SimpleRouteCase
    describe "rendering a normal template with full path without layout"
    
    get "/render_template/without_layout"
    assert_body   "Hello from basic.html.erb"
    assert_status 200
  end
  
  class TestTemplateRenderInTopDirectory < SimpleRouteCase
    describe "rendering a template not in a subdirectory"
    
    get "/render_template/without_layout/in_top_directory"
    assert_body   "Elastica"
    assert_status 200
  end

  class TestTemplateRenderInTopDirectoryWithSlash < SimpleRouteCase
    describe "rendering a template not in a subdirectory with a leading slash"
    
    get "/render_template/without_layout/in_top_directory_with_slash"
    assert_body   "Elastica"
    assert_status 200
  end
  
  class TestTemplateRenderWithLocals < SimpleRouteCase
    describe "rendering a template with local variables"
    
    get "/render_template/without_layout/with_locals"
    assert_body   "The secret is area51"
    assert_status 200
  end
    
  class WithLayoutController < ::ApplicationController
    
    self.view_paths = [ActionView::Template::FixturePath.new(
      "test/basic.html.erb"          => "Hello from basic.html.erb",
      "shared.html.erb"              => "Elastica",
      "layouts/application.html.erb" => "<%= yield %>, I'm here!",
      "layouts/greetings.html.erb"   => "<%= yield %>, I wish thee well."
    )]
    
    def index
      render :template => "test/basic"
    end
    
    def with_layout
      render :template => "test/basic", :layout => true
    end
    
    def with_layout_false
      render :template => "test/basic", :layout => false
    end
    
    def with_layout_nil
      render :template => "test/basic", :layout => nil
    end
    
    def with_custom_layout
      render :template => "test/basic", :layout => "greetings"
    end
  end
  
  class TestTemplateRenderWithLayout < SimpleRouteCase
    describe "rendering a normal template with full path with layout"
    
    get "/render_template/with_layout"
    assert_body   "Hello from basic.html.erb, I'm here!"
    assert_status 200
  end
  
  class TestTemplateRenderWithLayoutTrue < SimpleRouteCase
    describe "rendering a normal template with full path with layout => :true"
    
    get "/render_template/with_layout/with_layout"
    assert_body   "Hello from basic.html.erb, I'm here!"
    assert_status 200
  end
  
  class TestTemplateRenderWithLayoutFalse < SimpleRouteCase
    describe "rendering a normal template with full path with layout => :false"
    
    get "/render_template/with_layout/with_layout_false"
    assert_body   "Hello from basic.html.erb"
    assert_status 200
  end
  
  class TestTemplateRenderWithLayoutNil < SimpleRouteCase
    describe "rendering a normal template with full path with layout => :nil"
    
    get "/render_template/with_layout/with_layout_nil"
    assert_body   "Hello from basic.html.erb"
    assert_status 200
  end
  
  class TestTemplateRenderWithCustomLayout < SimpleRouteCase
    describe "rendering a normal template with full path with layout => 'greetings'"
    
    get "/render_template/with_layout/with_custom_layout"
    assert_body   "Hello from basic.html.erb, I wish thee well."
    assert_status 200
  end
  
  module Compatibility
    class WithoutLayoutController < ActionController::Base
      self.view_paths = [ActionView::Template::FixturePath.new(
        "test/basic.html.erb" => "Hello from basic.html.erb",
        "shared.html.erb"     => "Elastica"
      )]

      def with_forward_slash
        render :template => "/test/basic"
      end
    end

    class TestTemplateRenderWithForwardSlash < SimpleRouteCase
      describe "rendering a normal template with full path starting with a leading slash"

      get "/render_template/compatibility/without_layout/with_forward_slash"
      assert_body   "Hello from basic.html.erb"
      assert_status 200
    end
  end
end