require 'abstract_unit'
require 'mocha/setup' # FIXME: stop using mocha

class TemplateEagerLoaderTest < ActiveSupport::TestCase
  module TemplateEagerLoaderTestHelper
    def subject
      @subject ||= ActionView::TemplateEagerLoader.new(resolver)
    end

    def resolver
      @resolver ||= mock
    end
  end

  include TemplateEagerLoaderTestHelper

  def setup
    subject.stubs(:path_names).with('people').returns(['index.html.erb'])
    subject.stubs(:view_paths).returns(['app/views/people/index.html.erb'])
  end

  class PrefixesReturnsPeople < TemplateEagerLoaderTest
    def setup
      super
      subject.stubs(:prefixes).returns(['people'])
    end

    def test_cache_templates_calls_find_all
      resolver.expects(:find_all).returns([])
      subject.eager_load
    end

    def test_compile_called
      template = mock
      resolver.stubs(:find_all).returns([template])
      template.expects(:compile!)
      subject.eager_load
    end

    def test_multiple_templates
      template1 = mock
      template2 = mock
      resolver.stubs(:find_all).returns([template1, template2])
      template1.expects(:compile!)
      template2.expects(:compile!)
      subject.eager_load
    end

    def test_instance_method_added
      template = ActionView::Template.new("<%= hello %>", "hello template", { format: :html }.fetch(:handler) { ActionView::Template::Handlers::ERB.new }, {:virtual_path => "hello"}.merge!({ format: :html }))
      resolver.stubs(:find_all).returns([template])
      subject.eager_load
      assert ActionView::CompiledTemplates.instance_methods.any? { |m| m.to_s.split('_')[1..2] == ["hello", "template"] }
    end

    def test_multiple_instance_methods_added
      template1 = ActionView::Template.new("<%= moi %>", "moi template", { format: :html }.fetch(:handler) { ActionView::Template::Handlers::ERB.new }, {:virtual_path => "moi"}.merge!({ format: :html }))
      template2 = ActionView::Template.new("<%= bonjour %>", "bonjour template", { format: :html }.fetch(:handler) { ActionView::Template::Handlers::ERB.new }, {:virtual_path => "bonjour"}.merge!({ format: :html }))
      resolver.stubs(:find_all).returns([template1, template2])
      subject.eager_load
      moi_found = false
      bonjour_found = false
      ActionView::CompiledTemplates.instance_methods.each do |m|
        if m.to_s.split('_')[1..2] == ["moi", "template"]
          moi_found = true
        elsif m.to_s.split('_')[1..2] == ["bonjour", "template"]
          bonjour_found = true
        end
      end
      assert moi_found && bonjour_found
    end

    class PartialTests < TemplateEagerLoaderTest
      def setup
        super
        subject.stubs(:path_names).with(anything).returns(['_partial.html.erb'])
      end

      def test_cache_templates_parses_partial_names
        resolver.expects(:find_all).with('partial', anything, anything, anything, anything, anything).returns([]).at_least_once
        subject.eager_load
      end

      def test_cache_templates_passes_right_locals_with_partial
        resolver.expects(:find_all).with('partial', anything, anything, anything, anything, %w(partial partial_counter partial_iteration)).returns([])
        resolver.expects(:find_all).with('partial', anything, anything, anything, anything, []).returns([])
        subject.eager_load
      end
    end

    def test_partials_and_locals_correct_when_not_a_partial
      resolver.expects(:find_all).with(anything, anything, false, anything, anything, []).returns([])
      subject.eager_load
    end

    def test_not_being_partial_does_not_lead_into_multiple_caching_attemps
      resolver.expects(:find_all).returns([]).at_most_once
      subject.eager_load
    end

    def test_details_have_correct_formats
      resolver.expects(:find_all).with(anything, anything, anything, has_entry(formats: [:html]), anything, anything).returns([])
      subject.eager_load
    end

    def test_formats_work_without_the_extension_in_filename
      subject.stubs(:path_names).with(anything).returns(['index.haml'])
      resolver.expects(:find_all).with(anything, anything, anything, has_entry(formats: [:html]), anything, anything).returns([])
      subject.eager_load
    end

    def test_details_locale_defaults_to_english
      resolver.expects(:find_all).with(anything, anything, anything, has_entry(locale: [:en]), anything, anything).returns([])
      subject.eager_load
    end

    def test_details_with_other_default_than_english
      I18n.stubs(:available_locales).returns([:other, :en])
      I18n.stubs(:default_locale).returns([:other])
      resolver.stubs(:find_all).returns([])
      resolver.expects(:find_all).with(anything, anything, anything, has_entry(locale: [:other, :en]), anything, anything).returns([])
      subject.eager_load
    end

    def test_details_locale_works_with_default_and_set_locale
      I18n.stubs(:available_locales).returns([:fi, :en, :cn])
      I18n.stubs(:default_locale).returns([:cn])
      I18n.stubs(:locale).returns([:fi])
      resolver.stubs(:find_all).returns([])
      resolver.expects(:find_all).with(anything, anything, anything, has_entry(locale: [:fi, :en, :cn]), anything, anything).returns([])
      subject.eager_load
    end


    def test_details_variants_is_not_set_when_view_is_not_a_variant
      resolver.expects(:find_all).with(anything, anything, anything, has_entry(variants: []), anything, anything).returns([])
      subject.eager_load
    end

    def test_details_variants_get_set_correctly
      subject.stubs(:path_names).with(anything).returns(['index.html+variant.erb'])
      resolver.expects(:find_all).with(anything, anything, anything, has_entry(variants: ['variant']), anything, anything).returns([])
      subject.eager_load
    end

    def test_cache_templates_action
      resolver.expects(:find_all).with('index', anything, anything, anything, anything, anything).returns([])
      subject.eager_load
    end

    def test_cache_templates_prefix
      resolver.expects(:find_all).with(anything, 'people', anything, anything, anything, anything).returns([])
      subject.eager_load
    end
  end

  class NestedPrefixes < TemplateEagerLoaderTest
    def setup
      super
      subject.stubs(:path_names).with('people/assets').returns(['index.html.erb'])
      subject.stubs(:view_paths).returns(['app/views/people/assets/index.html.erb'])
      resolver.stubs(:find_all).returns([])
    end

    def test_two_layer_nested_prefixes_calls_view_paths
      subject.expects(:view_paths).returns(['app/views/people/assets/index.html.erb'])
      subject.eager_load
    end

    def test_two_layer_nested_prefixes_returns_desired_results
      resolver.expects(:find_all).with(anything,'people/assets', anything, anything, anything, anything).returns([])
      subject.eager_load
    end
  end

  class Prefixes < TemplateEagerLoaderTest
    def setup
      super
      resolver.stubs(:find_all).returns([])
    end

    def test_prefixes_calls_view_paths
      subject.expects(:view_paths).returns(['app/views/people/index.html.erb'])
      subject.eager_load
    end

    def test_prefixes_returns_desired_results
      resolver.expects(:find_all).with(anything,'people', anything, anything, anything, anything).returns([])
      subject.eager_load
    end

    def test_cache_templates_multiple_prefixes
      subject.stubs(:prefixes).returns(['prefix1', 'prefix2'])
      subject.stubs(:path_names).with('prefix1').returns(['index.html.erb'])
      subject.stubs(:path_names).with('prefix2').returns(['index.html.erb'])
      resolver.expects(:find_all).with(anything, 'prefix1', anything, anything, anything, anything).returns([])
      resolver.expects(:find_all).with(anything, 'prefix2', anything, anything, anything, anything).returns([])
      subject.eager_load
    end
  end
end
