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
                  foo_html: "<strong>bar</strong>",
                  baz: {
                    html: "<strong>baz</strong>"
                  }
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

      def test_lazy_lookup
        @controller.stub :action_name, :index do
          assert_equal "bar", @controller.t(".foo")
        end
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
        end
      end

      def test_localize
        time, expected = Time.gm(2000), "Sat, 01 Jan 2000 00:00:00 +0000"
        I18n.stub :localize, expected do
          assert_equal expected, @controller.l(time)
        end
      end

      def test_html_suffix
        @controller.stub :action_name, :index do
          foo_html = @controller.t(".foo_html")

          assert_equal "<strong>bar</strong>", foo_html
          assert foo_html.html_safe?
        end
      end

      def test_html_last_element
        @controller.stub :action_name, :index do
          baz_html = @controller.t(".baz.html")

          assert_equal "<strong>baz</strong>", baz_html
          assert baz_html.html_safe?
        end
      end
    end
  end
end
