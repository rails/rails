require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module RenderTemplate
  class WithoutLayoutController < ActionController::Base
    
    self.view_paths = [ActionView::FixtureResolver.new(
      "test/basic.html.erb"      => "Hello from basic.html.erb",
      "shared.html.erb"          => "Elastica",
      "locals.html.erb"          => "The secret is <%= secret %>",
      "xml_template.xml.builder" => "xml.html do\n  xml.p 'Hello'\nend"
    )]
    
    def index
      render :template => "test/basic"
    end
    
    def index_without_key
      render "test/basic"
    end

    def in_top_directory
      render :template => 'shared'
    end

    def in_top_directory_with_slash
      render :template => '/shared'
    end
    
    def in_top_directory_with_slash_without_key
      render '/shared'
    end
    
    def with_locals
      render :template => "locals", :locals => { :secret => 'area51' }
    end
    
    def builder_template
      render :template => "xml_template"
    end
  end
  
  class TestWithoutLayout < SimpleRouteCase
    testing RenderTemplate::WithoutLayoutController
    
    test "rendering a normal template with full path without layout" do
      get :index
      assert_response "Hello from basic.html.erb"
    end
    
    test "rendering a normal template with full path without layout without key" do
      get :index_without_key
      assert_response "Hello from basic.html.erb"
    end
    
    test "rendering a template not in a subdirectory" do
      get :in_top_directory
      assert_response "Elastica"
    end
    
    test "rendering a template not in a subdirectory with a leading slash" do
      get :in_top_directory_with_slash
      assert_response "Elastica"
    end
    
    test "rendering a template not in a subdirectory with a leading slash without key" do
      get :in_top_directory_with_slash_without_key
      assert_response "Elastica"
    end
    
    test "rendering a template with local variables" do
      get :with_locals
      assert_response "The secret is area51"
    end
    
    test "rendering a builder template" do
      get :builder_template
      assert_response "<html>\n  <p>Hello</p>\n</html>\n"
    end
  end
    
  class WithLayoutController < ::ApplicationController
    self.view_paths = [ActionView::FixtureResolver.new(
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
  
  class TestWithLayout < SimpleRouteCase
    describe "Rendering with :template using implicit or explicit layout"

    test "rendering with implicit layout" do
      get "/render_template/with_layout"

      assert_body "Hello from basic.html.erb, I'm here!"
      assert_status 200
    end

    test "rendering with layout => :true" do
      get "/render_template/with_layout/with_layout"

      assert_body "Hello from basic.html.erb, I'm here!"
      assert_status 200
    end

    test "rendering with layout => :false" do
      get "/render_template/with_layout/with_layout_false"

      assert_body "Hello from basic.html.erb"
      assert_status 200
    end

    test "rendering with layout => :nil" do
      get "/render_template/with_layout/with_layout_nil"

      assert_body "Hello from basic.html.erb"
      assert_status 200
    end

    test "rendering layout => 'greetings'" do
      get "/render_template/with_layout/with_custom_layout"

      assert_body "Hello from basic.html.erb, I wish thee well."
      assert_status 200
    end
  end

  module Compatibility
    class WithoutLayoutController < ActionController::Base
      self.view_paths = [ActionView::FixtureResolver.new(
        "test/basic.html.erb" => "Hello from basic.html.erb",
        "shared.html.erb"     => "Elastica"
      )]

      def with_forward_slash
        render :template => "/test/basic"
      end
    end

    class TestTemplateRenderWithForwardSlash < SimpleRouteCase
      test "rendering a normal template with full path starting with a leading slash" do
        get "/render_template/compatibility/without_layout/with_forward_slash"

        assert_body "Hello from basic.html.erb"
        assert_status 200
      end
    end
  end
end