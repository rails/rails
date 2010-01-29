require 'abstract_unit'

module AbstractController
  module Testing

    class ControllerRenderer < AbstractController::Base
      include AbstractController::Rendering

      def _prefix
        "renderer"
      end

      self.view_paths = [ActionView::FixtureResolver.new(
        "template.erb" => "With Template",
        "renderer/default.erb" => "With Default",
        "renderer/string.erb" => "With String",
        "renderer/symbol.erb" => "With Symbol",
        "renderer/template_name.erb" => "With Template Name",
        "string/with_path.erb" => "With String With Path",
        "some/file.erb" => "With File",
        "with_format.html.erb" => "With html format",
        "with_format.xml.erb" => "With xml format",
        "with_locale.en.erb" => "With en locale",
        "with_locale.pl.erb" => "With pl locale"
      )]

      def template
        render :template => "template"
      end

      def file
        render :file => "some/file"
      end

      def inline
        render :inline => "With <%= :Inline %>"
      end

      def text
        render :text => "With Text"
      end

      def default
        render
      end

      def string
        render "string"
      end

      def string_with_path
        render "string/with_path"
      end

      def symbol
        render :symbol
      end

      def template_name
        render :_template_name => :template_name
      end

      def object
        render :_template => ActionView::Template::Text.new("With Object")
      end

      def with_html_format
        render :template => "with_format", :format => :html
      end

      def with_xml_format
        render :template => "with_format", :format => :xml
      end

      def with_en_locale
        render :template => "with_locale"
      end

      def with_pl_locale
        render :template => "with_locale", :locale => :pl
      end
    end

    class TestRenderer < ActiveSupport::TestCase

      def setup
        @controller = ControllerRenderer.new
      end

      def test_render_template
        @controller.process(:template)
        assert_equal "With Template", @controller.response_body
      end

      def test_render_file
        @controller.process(:file)
        assert_equal "With File", @controller.response_body
      end

      def test_render_inline
        @controller.process(:inline)
        assert_equal "With Inline", @controller.response_body
      end

      def test_render_text
        @controller.process(:text)
        assert_equal "With Text", @controller.response_body
      end

      def test_render_default
        @controller.process(:default)
        assert_equal "With Default", @controller.response_body
      end

      def test_render_string
        @controller.process(:string)
        assert_equal "With String", @controller.response_body
      end

      def test_render_symbol
        @controller.process(:symbol)
        assert_equal "With Symbol", @controller.response_body
      end

      def test_render_string_with_path
        @controller.process(:string_with_path)
        assert_equal "With String With Path", @controller.response_body
      end

      def test_render_template_name
        @controller.process(:template_name)
        assert_equal "With Template Name", @controller.response_body
      end

      def test_render_object
        @controller.process(:object)
        assert_equal "With Object", @controller.response_body
      end

      def test_render_with_html_format
        @controller.process(:with_html_format)
        assert_equal "With html format", @controller.response_body
      end

      def test_render_with_xml_format
        @controller.process(:with_xml_format)
        assert_equal "With xml format", @controller.response_body
      end

      def test_render_with_en_locale
        @controller.process(:with_en_locale)
        assert_equal "With en locale", @controller.response_body
      end

      def test_render_with_pl_locale
        @controller.process(:with_pl_locale)
        assert_equal "With pl locale", @controller.response_body
      end
    end
  end
end
