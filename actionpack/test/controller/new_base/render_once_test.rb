require 'abstract_unit'

module RenderTemplate
  class RenderOnceController < ActionController::Base
    layout false

    RESOLVER = ActionView::FixtureResolver.new(
      "test/a.html.erb"       => "a",
      "test/b.html.erb"       => "<>",
      "test/c.html.erb"       => "c",
      "test/one.html.erb"     => "<%= render :once => 'result' %>",
      "test/two.html.erb"     => "<%= render :once => 'result' %>",
      "test/three.html.erb"   => "<%= render :once => 'result' %>",
      "test/result.html.erb"  => "YES!",
      "other/result.html.erb" => "NO!",
      "layouts/test.html.erb" => "l<%= yield %>l"
    )

    self.view_paths = [RESOLVER]

    def _prefixes
      %w(test)
    end

    def multiple
      render :once => %w(a b c)
    end

    def once
      render :once => %w(one two three)
    end

    def duplicate
      render :once => %w(a a a)
    end

    def with_layout
      render :once => %w(a b c), :layout => "test"
    end

    def with_prefix
      render :once => "result", :prefixes => %w(other)
    end

    def with_nil_prefix
      render :once => "test/result", :prefixes => []
    end
  end

  module Tests
    def test_mutliple_arguments_get_all_rendered
      get :multiple
      assert_response "a\n<>\nc"
    end

    def test_referenced_templates_get_rendered_once
      get :once
      assert_response "YES!\n\n"
    end

    def test_duplicated_templates_get_rendered_once
      get :duplicate
      assert_response "a"
    end

    def test_layout_wraps_all_rendered_templates
      get :with_layout
      assert_response "la\n<>\ncl"
    end

    def test_with_prefix_option
      get :with_prefix
      assert_response "NO!"
    end

    def test_with_nil_prefix_option
      get :with_nil_prefix
      assert_response "YES!"
    end
  end

  class TestRenderOnce < Rack::TestCase
    testing RenderTemplate::RenderOnceController
    include Tests
  end
end
