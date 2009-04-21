require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module ControllerLayouts
  class ImplicitController < ::ApplicationController
    
    self.view_paths = [ActionView::FixtureTemplate::FixturePath.new(
      "layouts/application.html.erb" => "OMG <%= yield %> KTHXBAI",
      "basic.html.erb" => "Hello world!"
    )]
    
    def index
      render :template => "basic"
    end
  end
  
  class TestImplicitLayout < SimpleRouteCase
    describe "rendering a normal template, but using the implicit layout"
    
    get "/controller_layouts/implicit/index"
    assert_body   "OMG Hello world! KTHXBAI"
    assert_status 200
  end
  
  class ImplicitNameController < ::ApplicationController
    
    self.view_paths = [ActionView::FixtureTemplate::FixturePath.new(
      "layouts/controller_layouts/implicit_name.html.erb" => "OMGIMPLICIT <%= yield %> KTHXBAI",
      "basic.html.erb" => "Hello world!"
    )]
        
    def index
      render :template => "basic"
    end
  end
  
  class TestImplicitNamedLayout < SimpleRouteCase
    describe "rendering a normal template, but using an implicit NAMED layout"
    
    get "/controller_layouts/implicit_name/index"
    assert_body   "OMGIMPLICIT Hello world! KTHXBAI"
    assert_status 200
  end
  
  
end