require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module RenderRjs

  class BasicController < ActionController::Base

    self.view_paths = [ActionView::FixtureResolver.new(
      "render_rjs/basic/index.js.rjs"          => "page[:customer].replace_html render(:partial => 'customer')",
      "render_rjs/basic/index_html.js.rjs"     => "page[:customer].replace_html :partial => 'customer'",
      "render_rjs/basic/_customer.js.erb"      => "JS Partial",
      "render_rjs/basic/_customer.html.erb"    => "HTML Partial",
      "render_rjs/basic/index_locale.js.rjs"   => "page[:customer].replace_html :partial => 'customer'",
      "render_rjs/basic/_customer.da.html.erb" => "Danish HTML Partial",
      "render_rjs/basic/_customer.da.js.erb"   => "Danish JS Partial"
    )]

    def index
      render
    end

    def index_locale
      old_locale, I18n.locale = I18n.locale, :da
    end

  end

  class TestBasic < SimpleRouteCase
    testing BasicController

    test "rendering a partial in an RJS template should pick the JS template over the HTML one" do
      get :index
      assert_response("$(\"customer\").update(\"JS Partial\");")
    end

    test "replacing an element with a partial in an RJS template should pick the HTML template over the JS one" do
      get :index_html
      assert_response("$(\"customer\").update(\"HTML Partial\");")
    end

    test "replacing an element with a partial in an RJS template with a locale should pick the localed HTML template" do
      get :index_locale, :format => :js
      assert_response("$(\"customer\").update(\"Danish HTML Partial\");")
    end

  end
end