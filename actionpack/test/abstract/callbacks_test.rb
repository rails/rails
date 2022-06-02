# frozen_string_literal: true

require "abstract_unit"

module AbstractController
  module Testing
    class ControllerWithCallbacks < AbstractController::Base
      include AbstractController::Callbacks
    end

    class Callback1 < ControllerWithCallbacks
      set_callback :process_action, :before, :first

      def first
        @text = "Hello world"
      end

      def index
        self.response_body = @text
      end
    end

    class TestCallbacks1 < ActiveSupport::TestCase
      test "basic callbacks work" do
        controller = Callback1.new
        controller.process(:index)
        assert_equal "Hello world", controller.response_body
      end
    end

    class Callback2 < ControllerWithCallbacks
      before_action :first
      after_action :second
      around_action :aroundz

      def first
        @text = "Hello world"
      end

      def second
        @second = "Goodbye"
      end

      def aroundz
        @aroundz = "FIRST"
        yield
        @aroundz += "SECOND"
      end

      def index
        @text ||= nil
        self.response_body = @text.to_s
      end
    end

    class Callback2Overwrite < Callback2
      before_action :first, except: :index
    end

    class TestCallbacks2 < ActiveSupport::TestCase
      def setup
        @controller = Callback2.new
      end

      test "before_action works" do
        @controller.process(:index)
        assert_equal "Hello world", @controller.response_body
      end

      test "after_action works" do
        @controller.process(:index)
        assert_equal "Goodbye", @controller.instance_variable_get("@second")
      end

      test "around_action works" do
        @controller.process(:index)
        assert_equal "FIRSTSECOND", @controller.instance_variable_get("@aroundz")
      end

      test "before_action with overwritten condition" do
        @controller = Callback2Overwrite.new
        @controller.process(:index)
        assert_equal "", @controller.response_body
      end
    end

    class Callback3 < ControllerWithCallbacks
      before_action do |c|
        c.instance_variable_set("@text", "Hello world")
      end

      after_action do |c|
        c.instance_variable_set("@second", "Goodbye")
      end

      def index
        self.response_body = @text
      end
    end

    class TestCallbacks3 < ActiveSupport::TestCase
      def setup
        @controller = Callback3.new
      end

      test "before_action works with procs" do
        @controller.process(:index)
        assert_equal "Hello world", @controller.response_body
      end

      test "after_action works with procs" do
        @controller.process(:index)
        assert_equal "Goodbye", @controller.instance_variable_get("@second")
      end
    end

    class CallbacksWithConditions < ControllerWithCallbacks
      before_action :list, only: :index
      before_action :authenticate, except: :index

      def index
        self.response_body = @list.join(", ")
      end

      def sekrit_data
        self.response_body = (@list + [@authenticated]).join(", ")
      end

      private
        def list
          @list = ["Hello", "World"]
        end

        def authenticate
          @list ||= []
          @authenticated = "true"
        end
    end

    class TestCallbacksWithConditions < ActiveSupport::TestCase
      def setup
        @controller = CallbacksWithConditions.new
      end

      test "when :only is specified, a before action is triggered on that action" do
        @controller.process(:index)
        assert_equal "Hello, World", @controller.response_body
      end

      test "when :only is specified, a before action is not triggered on other actions" do
        @controller.process(:sekrit_data)
        assert_equal "true", @controller.response_body
      end

      test "when :except is specified, an after action is not triggered on that action" do
        @controller.process(:index)
        assert_not @controller.instance_variable_defined?("@authenticated")
      end
    end

    class CallbacksWithReusedConditions < ControllerWithCallbacks
      options = { only: :index }
      before_action :list, options
      before_action :authenticate, options

      def index
        self.response_body = @list.join(", ")
      end

      def public_data
        @authenticated = "false"
        self.response_body = @authenticated
      end

      private
        def list
          @list = ["Hello", "World"]
        end

        def authenticate
          @list ||= []
          @authenticated = "true"
        end
    end

    class TestCallbacksWithReusedConditions < ActiveSupport::TestCase
      def setup
        @controller = CallbacksWithReusedConditions.new
      end

      test "when :only is specified, both actions triggered on that action" do
        @controller.process(:index)
        assert_equal "Hello, World", @controller.response_body
        assert_equal "true", @controller.instance_variable_get("@authenticated")
      end

      test "when :only is specified, both actions are not triggered on other actions" do
        @controller.process(:public_data)
        assert_equal "false", @controller.response_body
      end
    end

    class CallbacksWithArrayConditions < ControllerWithCallbacks
      before_action :list, only: [:index, :listy]
      before_action :authenticate, except: [:index, :listy]

      def index
        self.response_body = @list.join(", ")
      end

      def sekrit_data
        self.response_body = (@list + [@authenticated]).join(", ")
      end

      private
        def list
          @list = ["Hello", "World"]
        end

        def authenticate
          @list = []
          @authenticated = "true"
        end
    end

    class TestCallbacksWithArrayConditions < ActiveSupport::TestCase
      def setup
        @controller = CallbacksWithArrayConditions.new
      end

      test "when :only is specified with an array, a before action is triggered on that action" do
        @controller.process(:index)
        assert_equal "Hello, World", @controller.response_body
      end

      test "when :only is specified with an array, a before action is not triggered on other actions" do
        @controller.process(:sekrit_data)
        assert_equal "true", @controller.response_body
      end

      test "when :except is specified with an array, an after action is not triggered on that action" do
        @controller.process(:index)
        assert_not @controller.instance_variable_defined?("@authenticated")
      end
    end

    class ChangedConditions < Callback2
      before_action :first, only: :index

      def not_index
        @text ||= nil
        self.response_body = @text.to_s
      end
    end

    class TestCallbacksWithChangedConditions < ActiveSupport::TestCase
      def setup
        @controller = ChangedConditions.new
      end

      test "when a callback is modified in a child with :only, it works for the :only action" do
        @controller.process(:index)
        assert_equal "Hello world", @controller.response_body
      end

      test "when a callback is modified in a child with :only, it does not work for other actions" do
        @controller.process(:not_index)
        assert_equal "", @controller.response_body
      end
    end

    class SetsResponseBody < ControllerWithCallbacks
      before_action :set_body

      def index
        self.response_body = "Fail"
      end

      def set_body
        self.response_body = "Success"
      end
    end

    class TestHalting < ActiveSupport::TestCase
      test "when a callback sets the response body, the action should not be invoked" do
        controller = SetsResponseBody.new
        controller.process(:index)
        assert_equal "Success", controller.response_body
      end
    end

    class CallbacksWithArgs < ControllerWithCallbacks
      set_callback :process_action, :before, :first

      def first
        @text = "Hello world"
      end

      def index(text)
        self.response_body = @text + text
      end
    end

    class TestCallbacksWithArgs < ActiveSupport::TestCase
      test "callbacks still work when invoking process with multiple arguments" do
        controller = CallbacksWithArgs.new
        controller.process(:index, " Howdy!")
        assert_equal "Hello world Howdy!", controller.response_body
      end
    end

    class TestCallbacksWithMissingConditions < ActiveSupport::TestCase
      class CallbacksWithMissingOnly < ControllerWithCallbacks
        before_action :callback, only: :showw

        def index
        end

        def show
        end

        private
          def callback
          end
      end

      test "callbacks raise exception when their 'only' condition is a missing action" do
        with_raise_on_missing_callback_actions do
          controller = CallbacksWithMissingOnly.new
          assert_raises(AbstractController::ActionNotFound) do
            controller.process(:index)
          end
        end
      end

      class CallbacksWithMissingOnlyInArray < ControllerWithCallbacks
        before_action :callback, only: [:index, :showw]

        def index
        end

        def show
        end

        private
          def callback
          end
      end

      test "callbacks raise exception when their 'only' array condition contains a missing action" do
        with_raise_on_missing_callback_actions do
          controller = CallbacksWithMissingOnlyInArray.new
          assert_raises(AbstractController::ActionNotFound) do
            controller.process(:index)
          end
        end
      end

      class CallbacksWithMissingExcept < ControllerWithCallbacks
        before_action :callback, except: :showw

        def index
        end

        def show
        end

        private
          def callback
          end
      end

      test "callbacks raise exception when their 'except' condition is a missing action" do
        with_raise_on_missing_callback_actions do
          controller = CallbacksWithMissingExcept.new
          assert_raises(AbstractController::ActionNotFound) do
            controller.process(:index)
          end
        end
      end

      class CallbacksWithMissingExceptInArray < ControllerWithCallbacks
        before_action :callback, except: [:index, :showw]

        def index
        end

        def show
        end

        private
          def callback
          end
      end

      test "callbacks raise exception when their 'except' array condition contains a missing action" do
        with_raise_on_missing_callback_actions do
          controller = CallbacksWithMissingExceptInArray.new
          assert_raises(AbstractController::ActionNotFound) do
            controller.process(:index)
          end
        end
      end

      class MultipleCallbacksWithMissingOnly < ControllerWithCallbacks
        before_action :callback1, :callback2, ->() { }, only: :showw

        def index
        end

        def show
        end

        private
          def callback1
          end

          def callback2
          end
      end

      test "raised exception message includes the names of callback actions and missing conditional action" do
        with_raise_on_missing_callback_actions do
          controller = MultipleCallbacksWithMissingOnly.new
          error = assert_raises(AbstractController::ActionNotFound) do
            controller.process(:index)
          end

          assert_includes error.message, ":callback1"
          assert_includes error.message, ":callback2"
          assert_includes error.message, "#<Proc:"
          assert_includes error.message, "only"
          assert_includes error.message, "showw"
        end
      end

      class BlockCallbackWithMissingOnly < ControllerWithCallbacks
        before_action only: :showw do
          # Callback body
        end

        def index
        end

        def show
        end
      end

      test "raised exception message includes a block callback" do
        with_raise_on_missing_callback_actions do
          controller = BlockCallbackWithMissingOnly.new
          error = assert_raises(AbstractController::ActionNotFound) do
            controller.process(:index)
          end

          assert_includes error.message, "#<Proc:"
        end
      end

      class CallbacksWithBothOnlyAndExcept < ControllerWithCallbacks
        before_action :callback, only: [:index, :show], except: :showw

        def index
        end

        def show
        end

        private
          def callback
          end
      end

      test "callbacks with both :only and :except options raise an exception with the correct message" do
        with_raise_on_missing_callback_actions do
          controller = CallbacksWithBothOnlyAndExcept.new
          error = assert_raises(AbstractController::ActionNotFound) do
            controller.process(:index)
          end

          assert_includes error.message, ":callback"
          assert_includes error.message, "except"
          assert_includes error.message, "showw"
        end
      end

      private
        def with_raise_on_missing_callback_actions
          old_raise_on_missing_callback_actions = ControllerWithCallbacks.raise_on_missing_callback_actions
          ControllerWithCallbacks.raise_on_missing_callback_actions = true
          yield
        ensure
          ControllerWithCallbacks.raise_on_missing_callback_actions = old_raise_on_missing_callback_actions
        end
    end
  end
end
