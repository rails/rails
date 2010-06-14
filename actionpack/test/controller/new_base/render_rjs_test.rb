require 'abstract_unit'

module RenderRjs
  class BasicController < ActionController::Base
    layout "application", :only => :index_respond_to

    self.view_paths = [ActionView::FixtureResolver.new(
      "layouts/application.html.erb"           => "",
      "render_rjs/basic/index.js.rjs"          => "page[:customer].replace_html render(:partial => 'customer')",
      "render_rjs/basic/index_html.js.rjs"     => "page[:customer].replace_html :partial => 'customer'",
      "render_rjs/basic/index_no_js.js.erb"    => "<%= render(:partial => 'developer') %>",
      "render_rjs/basic/_customer.js.erb"      => "JS Partial",
      "render_rjs/basic/_customer.html.erb"    => "HTML Partial",
      "render_rjs/basic/_developer.html.erb"   => "HTML Partial",
      "render_rjs/basic/index_locale.js.rjs"   => "page[:customer].replace_html :partial => 'customer'",
      "render_rjs/basic/_customer.da.html.erb" => "Danish HTML Partial",
      "render_rjs/basic/_customer.da.js.erb"   => "Danish JS Partial"
    )]

    def index
      render
    end

    def index_respond_to
      respond_to do |format|
        format.js { render :action => "index_no_js" }
      end
    end

    def index_locale
      self.locale = :da
    end
  end

  class TestBasic < Rack::TestCase
    testing BasicController

    def setup
      @old_locale = I18n.locale
    end

    def teardown
      I18n.locale = @old_locale
    end

    test "rendering a partial in an RJS template should pick the JS template over the HTML one" do
      get :index, "format" => "js"
      assert_response("$(\"customer\").update(\"JS Partial\");")
    end

    test "rendering a partial in an RJS template should pick the HTML one if no JS is available" do
      get :index_no_js, "format" => "js"
      assert_response("HTML Partial")
    end

    test "rendering a partial in an RJS template should pick the HTML one if no JS is available on respond_to" do
      get :index_respond_to, "format" => "js"
      assert_response("HTML Partial")
    end

    test "replacing an element with a partial in an RJS template should pick the HTML template over the JS one" do
      get :index_html, "format" => "js"
      assert_response("$(\"customer\").update(\"HTML Partial\");")
    end

    test "replacing an element with a partial in an RJS template with a locale should pick the localed HTML template" do
      get :index_locale, "format" => "js"
      assert_response("$(\"customer\").update(\"Danish HTML Partial\");")
    end
  end
end
