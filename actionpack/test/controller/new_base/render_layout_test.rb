# frozen_string_literal: true

require "abstract_unit"
require "test_renderable"

module ControllerLayouts
  class ImplicitController < ::ApplicationController
    self.view_paths = [ActionView::FixtureResolver.new(
      "layouts/application.html.erb" => "Main <%= yield %> Layout",
      "layouts/override.html.erb"    => "Override! <%= yield %>",
      "basic.html.erb"               => "Hello world!",
      "controller_layouts/implicit/layout_false.html.erb" => "hi(layout_false.html.erb)"
    )]

    def index
      render template: "basic"
    end

    def override
      render template: "basic", layout: "override"
    end

    def override_renderable
      render TestRenderable.new, layout: "override"
    end

    def layout_false
      render layout: false
    end

    def builder_override
    end
  end

  class ImplicitNameController < ::ApplicationController
    self.view_paths = [ActionView::FixtureResolver.new(
      "layouts/controller_layouts/implicit_name.html.erb" => "Implicit <%= yield %> Layout",
      "basic.html.erb" => "Hello world!"
    )]

    def index
      render template: "basic"
    end

    def renderable
      render TestRenderable.new
    end
  end

  class RenderLayoutTest < Rack::TestCase
    test "rendering a normal template, but using the implicit layout" do
      get "/controller_layouts/implicit/index"

      assert_body   "Main Hello world! Layout"
      assert_status 200
    end

    test "rendering a normal template, but using an implicit NAMED layout" do
      get "/controller_layouts/implicit_name/index"

      assert_body "Implicit Hello world! Layout"
      assert_status 200
    end

    test "rendering a renderable object, using the implicit layout" do
      get "/controller_layouts/implicit_name/renderable"

      assert_body "Implicit Hello, World! Layout"
      assert_status 200
    end

    test "rendering a renderable object, using the override layout" do
      get "/controller_layouts/implicit/override_renderable"

      assert_body "Override! Hello, World!"
      assert_status 200
    end

    test "overriding an implicit layout with render :layout option" do
      get "/controller_layouts/implicit/override"
      assert_body "Override! Hello world!"
    end
  end

  class LayoutOptionsTest < Rack::TestCase
    testing ControllerLayouts::ImplicitController

    test "rendering with :layout => false leaves out the implicit layout" do
      get :layout_false
      assert_response "hi(layout_false.html.erb)"
    end
  end

  class MismatchFormatController < ::ApplicationController
    self.view_paths = [ActionView::FixtureResolver.new(
      "layouts/application.html.erb" => "<html><%= yield %></html>",
      "controller_layouts/mismatch_format/index.xml.builder" => "xml.instruct!",
      "controller_layouts/mismatch_format/implicit.builder" => "xml.instruct!",
      "controller_layouts/mismatch_format/explicit.js.erb" => "alert('foo');"
    )]

    def explicit
      render layout: "application"
    end
  end

  class MismatchFormatTest < Rack::TestCase
    testing ControllerLayouts::MismatchFormatController

    XML_INSTRUCT = %Q(<?xml version="1.0" encoding="UTF-8"?>\n)

    test "if XML is selected, an HTML template is not also selected" do
      get :index, params: { format: "xml" }
      assert_response XML_INSTRUCT
    end

    test "if XML is implicitly selected, an HTML template is not also selected" do
      get :implicit
      assert_response XML_INSTRUCT
    end

    test "a layout for JS is ignored even if explicitly provided for HTML" do
      get :explicit, params: { format: "js" }
      assert_response "alert('foo');"
    end
  end

  class FalseLayoutMethodController < ::ApplicationController
    self.view_paths = [ActionView::FixtureResolver.new(
      "controller_layouts/false_layout_method/index.js.erb" => "alert('foo');"
    )]

    layout :which_layout?

    def which_layout?
      false
    end

    def index
    end
  end

  class FalseLayoutMethodTest < Rack::TestCase
    testing ControllerLayouts::FalseLayoutMethodController

    test "access false layout returned by a method/proc" do
      get :index, params: { format: "js" }
      assert_response "alert('foo');"
    end
  end
end
