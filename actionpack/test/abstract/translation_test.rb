# frozen_string_literal: true

require 'abstract_unit'

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
            two: 'bar',
          },
          abstract_controller: {
            testing: {
              translation: {
                index: {
                  foo: 'bar',
                },
                no_action: 'no_action_tr',
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

      def test_raises_missing_translation_message_with_raise_config_option
        AbstractController::Translation.raise_on_missing_translations = true

        assert_raise(I18n::MissingTranslationData) do
          @controller.t('translations.missing')
        end
      ensure
        AbstractController::Translation.raise_on_missing_translations = false
      end

      def test_raises_missing_translation_message_with_raise_option
        assert_raise(I18n::MissingTranslationData) do
          @controller.t(:"translations.missing", raise: true)
        end
      end

      def test_lazy_lookup
        @controller.stub :action_name, :index do
          assert_equal 'bar', @controller.t('.foo')
        end
      end

      def test_lazy_lookup_with_symbol
        @controller.stub :action_name, :index do
          assert_equal 'bar', @controller.t(:'.foo')
        end
      end

      def test_lazy_lookup_fallback
        @controller.stub :action_name, :index do
          assert_equal 'no_action_tr', @controller.t(:'.no_action')
        end
      end

      def test_default_translation
        @controller.stub :action_name, :index do
          assert_equal 'bar', @controller.t('one.two')
          assert_equal 'baz', @controller.t('.twoz', default: ['baz', :twoz])
        end
      end

      def test_localize
        time, expected = Time.gm(2000), 'Sat, 01 Jan 2000 00:00:00 +0000'
        I18n.stub :localize, expected do
          assert_equal expected, @controller.l(time)
        end
      end
    end
  end
end
