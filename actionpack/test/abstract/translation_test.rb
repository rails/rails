# frozen_string_literal: true

require "abstract_unit"

module AbstractController
  module Testing
    class TranslationController < AbstractController::Base
      include AbstractController::Translation
    end

    class TranslationControllerTest < ActiveSupport::TestCase
      def setup
        @controller = TranslationController.new
        I18n.backend.store_translations(:en,
          one: {
            two: "bar",
          },
          abstract_controller: {
            testing: {
              translation: {
                index: {
                  foo: "bar",
                  hello: "<a>Hello World</a>",
                  hello_html: "<a>Hello World</a>",
                  interpolated_html: "<a>Hello %{word}</a>",
                  nested: { html: "<a>nested</a>" }
                },
                no_action: "no_action_tr",
              },
            },
          })
      end

      def test_action_controller_base_responds_to_translate
        assert_respond_to @controller, :translate
      end

      def test_action_controller_base_responds_to_t
        assert_respond_to @controller, :t
      end

      def test_action_controller_base_responds_to_localize
        assert_respond_to @controller, :localize
      end

      def test_action_controller_base_responds_to_l
        assert_respond_to @controller, :l
      end

      def test_raises_missing_translation_message_with_raise_option
        assert_raise(I18n::MissingTranslationData) do
          @controller.t(:"translations.missing", raise: true)
        end
      end

      def test_lazy_lookup
        @controller.stub :action_name, :index do
          assert_equal "bar", @controller.t(".foo")
        end
      end

      def test_nil_key_lookup
        default = "foo"
        assert_equal default, @controller.t(nil, default: default)
      end

      def test_lazy_lookup_with_symbol
        @controller.stub :action_name, :index do
          assert_equal "bar", @controller.t(:'.foo')
        end
      end

      def test_lazy_lookup_fallback
        @controller.stub :action_name, :index do
          assert_equal "no_action_tr", @controller.t(:'.no_action')
        end
      end

      def test_default_translation
        @controller.stub :action_name, :index do
          assert_equal "bar", @controller.t("one.two")
          assert_equal "baz", @controller.t(".twoz", default: ["baz", :twoz])
        end
      end

      def test_default_translation_as_unsafe_html
        @controller.stub :action_name, :index do
          translation = @controller.t(".twoz", default: ["<tag>"])
          assert_equal "<tag>", translation
          assert_equal false, translation.html_safe?
        end
      end

      def test_default_translation_as_safe_html
        @controller.stub :action_name, :index do
          translation = @controller.t(".twoz_html", default: ["<tag>"])
          assert_equal "&lt;tag&gt;", translation
          assert_equal true, translation.html_safe?
        end
      end

      def test_default_translation_with_raise_as_unsafe_html
        @controller.stub :action_name, :index do
          translation = @controller.t(".twoz", raise: true, default: ["<tag>"])
          assert_equal "<tag>", translation
          assert_equal false, translation.html_safe?
        end
      end

      def test_default_translation_with_raise_as_safe_html
        @controller.stub :action_name, :index do
          translation = @controller.t(".twoz_html", raise: true, default: ["<tag>"])
          assert_equal "&lt;tag&gt;", translation
          assert_equal true, translation.html_safe?
        end
      end

      def test_localize
        time, expected = Time.gm(2000), "Sat, 01 Jan 2000 00:00:00 +0000"
        I18n.stub :localize, expected do
          assert_equal expected, @controller.l(time)
        end
      end

      def test_translate_does_not_mark_plain_text_as_safe_html
        @controller.stub :action_name, :index do
          translation = @controller.t(".hello")
          assert_equal "<a>Hello World</a>", translation
          assert_equal false, translation.html_safe?
        end
      end

      def test_translate_marks_translations_with_a_html_suffix_as_safe_html
        @controller.stub :action_name, :index do
          translation = @controller.t(".hello_html")
          assert_equal "<a>Hello World</a>", translation
          assert_equal true, translation.html_safe?
        end
      end

      def test_translate_marks_translation_with_nested_html_key
        @controller.stub :action_name, :index do
          translation = @controller.t(".nested.html")
          assert_equal "<a>nested</a>", translation
          assert_equal true, translation.html_safe?
        end
      end

      def test_translate_escapes_interpolations_in_translations_with_a_html_suffix
        word_struct = Struct.new(:to_s)
        @controller.stub :action_name, :index do
          translation = @controller.t(".interpolated_html", word: "<World>")
          assert_equal "<a>Hello &lt;World&gt;</a>", translation
          assert_equal true, translation.html_safe?

          translation = @controller.t(".interpolated_html", word: word_struct.new("<World>"))
          assert_equal "<a>Hello &lt;World&gt;</a>", translation
          assert_equal true, translation.html_safe?
        end
      end

      def test_translate_marks_translation_with_missing_html_key_as_safe_html
        @controller.stub :action_name, :index do
          translation = @controller.t("<tag>.html")
          assert_equal false, translation.html_safe?
          assert_equal "Translation missing: en.<tag>.html", translation
        end
      end
      def test_translate_marks_translation_with_missing_nested_html_key_as_safe_html
        @controller.stub :action_name, :index do
          translation = @controller.t(".<tag>.html")
          assert_equal false, translation.html_safe?
          assert_equal(<<~MSG.strip, translation)
            Translation missing. Options considered were:
            - en.abstract_controller.testing.translation.index.<tag>.html
            - en.abstract_controller.testing.translation.<tag>.html
          MSG
        end
      end
    end
  end
end
