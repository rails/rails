require 'abstract_unit'

module RenderTemplate
  class RenderOnceController < ActionController::Base
    layout false

    RESOLVER = ActionView::FixtureResolver.new(
      "test/a.html.erb"       => "a",
      "test/b.html.erb"       => "<>",
      "test/c.html.erb"       => "c",
      "test/one.html.erb"     => "<%= render :once => 'test/result' %>",
      "test/two.html.erb"     => "<%= render :once => 'test/result' %>",
      "test/three.html.erb"   => "<%= render :once => 'test/result' %>",
      "test/result.html.erb"  => "YES!",
      "layouts/test.html.erb" => "l<%= yield %>l"
    )

    self.view_paths = [RESOLVER]

    def multiple
      render :once => %w(test/a test/b test/c)
    end

    def once
      render :once => %w(test/one test/two test/three)
    end

    def duplicate
      render :once => %w(test/a test/a test/a)
    end

    def with_layout
      render :once => %w(test/a test/b test/c), :layout => "test"
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
  end

  class TestWithResolverCache < Rack::TestCase
    testing RenderTemplate::RenderOnceController
    include Tests
  end

  class TestWithoutResolverCache < Rack::TestCase
    testing RenderTemplate::RenderOnceController
    include Tests

    def setup
      RenderTemplate::RenderOnceController::RESOLVER.stubs(:caching?).returns(false)
    end
  end
end
