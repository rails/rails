# frozen_string_literal: true

require "abstract_unit"

module RenderHtml
  class MinimalController < ActionController::Metal
    include AbstractController::Rendering
    include ActionController::Rendering

    def index
      render html: "Hello World!"
    end
  end

  class SimpleController < ActionController::Base
    self.view_paths = [ActionView::FixtureResolver.new]

    def index
      render html: "hello david"
    end
  end

  class WithLayoutController < ::ApplicationController
    self.view_paths = [ActionView::FixtureResolver.new(
      "layouts/application.html.erb" => "<%= yield %>, I'm here!",
      "layouts/greetings.html.erb"   => "<%= yield %>, I wish thee well.",
      "layouts/ivar.html.erb"        => "<%= yield %>, <%= @ivar %>"
    )]

    def index
      render html: "hello david"
    end

    def custom_code
      render html: "hello world", status: 404
    end

    def with_custom_code_as_string
      render html: "hello world", status: "404 Not Found"
    end

    def with_nil
      render html: nil
    end

    def with_nil_and_status
      render html: nil, status: 403
    end

    def with_false
      render html: false
    end

    def with_layout_true
      render html: "hello world", layout: true
    end

    def with_layout_false
      render html: "hello world", layout: false
    end

    def with_layout_nil
      render html: "hello world", layout: nil
    end

    def with_custom_layout
      render html: "hello world", layout: "greetings"
    end

    def with_ivar_in_layout
      @ivar = "hello world"
      render html: "hello world", layout: "ivar"
    end

    def with_unsafe_html_tag
      render html: "<p>hello world</p>", layout: nil
    end

    def with_safe_html_tag
      render html: "<p>hello world</p>".html_safe, layout: nil
    end
  end

  class RenderHtmlTest < Rack::TestCase
    test "rendering text from a minimal controller" do
      get "/render_html/minimal/index"
      assert_body "Hello World!"
      assert_status 200
    end

    test "rendering text from an action with default options renders the text with the layout" do
      with_routing do |set|
        set.draw { ActiveSupport::Deprecation.silence { get ":controller", action: "index" } }

        get "/render_html/simple"
        assert_body "hello david"
        assert_status 200
      end
    end

    test "rendering text from an action with default options renders the text without the layout" do
      with_routing do |set|
        set.draw { ActiveSupport::Deprecation.silence { get ":controller", action: "index" } }

        get "/render_html/with_layout"

        assert_body "hello david"
        assert_status 200
      end
    end

    test "rendering text, while also providing a custom status code" do
      get "/render_html/with_layout/custom_code"

      assert_body "hello world"
      assert_status 404
    end

    test "rendering text with nil returns an empty body" do
      get "/render_html/with_layout/with_nil"

      assert_body ""
      assert_status 200
    end

    test "Rendering text with nil and custom status code returns an empty body and the status" do
      get "/render_html/with_layout/with_nil_and_status"

      assert_body ""
      assert_status 403
    end

    test "rendering text with false returns the string 'false'" do
      get "/render_html/with_layout/with_false"

      assert_body "false"
      assert_status 200
    end

    test "rendering text with layout: true" do
      get "/render_html/with_layout/with_layout_true"

      assert_body "hello world, I'm here!"
      assert_status 200
    end

    test "rendering text with layout: 'greetings'" do
      get "/render_html/with_layout/with_custom_layout"

      assert_body "hello world, I wish thee well."
      assert_status 200
    end

    test "rendering text with layout: false" do
      get "/render_html/with_layout/with_layout_false"

      assert_body "hello world"
      assert_status 200
    end

    test "rendering text with layout: nil" do
      get "/render_html/with_layout/with_layout_nil"

      assert_body "hello world"
      assert_status 200
    end

    test "rendering html should escape the string if it is not html safe" do
      get "/render_html/with_layout/with_unsafe_html_tag"

      assert_body "&lt;p&gt;hello world&lt;/p&gt;"
      assert_status 200
    end

    test "rendering html should not escape the string if it is html safe" do
      get "/render_html/with_layout/with_safe_html_tag"

      assert_body "<p>hello world</p>"
      assert_status 200
    end

    test "rendering from minimal controller returns response with text/html content type" do
      get "/render_html/minimal/index"
      assert_content_type "text/html; charset=utf-8"
    end

    test "rendering from normal controller returns response with text/html content type" do
      get "/render_html/simple/index"
      assert_content_type "text/html; charset=utf-8"
    end
  end
end
