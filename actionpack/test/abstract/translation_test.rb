require 'abstract_unit'

module AbstractController
  module Testing
    class TranslationController < AbstractController::Base
      include AbstractController::Translation
    end

    class TranslationControllerTest < ActiveSupport::TestCase
      def setup
        @controller = TranslationController.new
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
        expected = 'bar'
        @controller.stubs(action_name: :index)
        I18n.stubs(:translate).with('abstract_controller.testing.translation.index.foo').returns(expected)
        assert_equal expected, @controller.t('.foo')
      end

      def test_default_translation
        key, expected = 'one.two', 'bar'
        I18n.stubs(:translate).with(key).returns(expected)
        assert_equal expected, @controller.t(key)
      end

      def test_localize
        time, expected = Time.gm(2000), 'Sat, 01 Jan 2000 00:00:00 +0000'
        I18n.stubs(:localize).with(time).returns(expected)
        assert_equal expected, @controller.l(time)
      end
    end
  end
end
