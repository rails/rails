require 'abstract_unit'

module AbstractController
  module Testing
  
    class CachedController < AbstractController::Base
      include AbstractController::RenderingController
      include AbstractController::LocalizedCache

      self.view_paths = [ActionView::FixtureResolver.new(
        "default.erb" => "With Default",
        "template.erb" => "With Template",
        "some/file.erb" => "With File",
        "template_name.erb" => "With Template Name"
      )]
    end

    class TestLocalizedCache < ActiveSupport::TestCase

      def setup
        @controller = CachedController.new
        CachedController.clear_template_caches!
      end

      def test_templates_are_cached
        @controller.render :template => "default.erb"
        assert_equal "With Default", @controller.response_body

        cached = @controller.class.template_cache
        assert_equal 1, cached.size
        assert_kind_of ActionView::Template, cached.values.first["default.erb"]
      end

      def test_cache_is_used
        CachedController.new.render :template => "default.erb"

        @controller.expects(:find_template).never
        @controller.render :template => "default.erb"

        assert_equal 1, @controller.class.template_cache.size
      end

      def test_cache_changes_with_locale
        CachedController.new.render :template => "default.erb"

        I18n.locale = :es
        @controller.render :template => "default.erb"

        assert_equal 2, @controller.class.template_cache.size
      ensure
        I18n.locale = :en
      end

    end

  end
end
