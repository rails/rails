require "abstract_unit"

class ActionController::Base
  class << self
    %w(append_around_action prepend_after_action prepend_around_action prepend_before_action skip_after_action skip_before_action).each do |pending|
      define_method(pending) do |*args|
        $stderr.puts "#{pending} unimplemented: #{args.inspect}"
      end unless method_defined?(pending)
    end

    def before_actions
      action_callbacks = _process_action_callbacks.select { |c| c.kind == :before }
      # NOTE: Even though we no longer refer to controller callbacks
      # as 'filters', they are still called filters in ActiveSupport::Callbacks
      action_callbacks.map!(&:raw_filter)
    end
  end
end

class ActionCallbackTest < ActionController::TestCase
  class TestController < ActionController::Base
    before_action :ensure_login
    after_action  :clean_up

    def show
      render inline: "ran action"
    end

    private
      def ensure_login
        @ran_action_callback ||= []
        @ran_action_callback << "ensure_login"
      end

      def clean_up
        @ran_after_action ||= []
        @ran_after_action << "clean_up"
      end
  end

  class ChangingTheRequirementsController < TestController
    before_action :ensure_login, except: [:go_wild]

    def go_wild
      render plain: "gobble"
    end
  end

  class TestMultipleActionCallbacksController < ActionController::Base
    before_action :try_1
    before_action :try_2
    before_action :try_3

    (1..3).each do |i|
      define_method "fail_#{i}" do
        render plain: i.to_s
      end
    end

    private
      (1..3).each do |i|
        define_method "try_#{i}" do
          instance_variable_set :@try, i
          if action_name == "fail_#{i}"
            head(404)
          end
        end
      end
  end

  class RenderingController < ActionController::Base
    before_action :before_action_rendering
    after_action :unreached_after_action

    def show
      @ran_action = true
      render inline: "ran action"
    end

    private
      def before_action_rendering
        @ran_action_callback ||= []
        @ran_action_callback << "before_action_rendering"
        render inline: "something else"
      end

      def unreached_after_action
        @ran_action_callback << "unreached_after_action_after_render"
      end
  end

  class RenderingForPrependAfterActionController < RenderingController
    prepend_after_action :unreached_prepend_after_action

    private
      def unreached_prepend_after_action
        @ran_action_callback << "unreached_preprend_after_action_after_render"
      end
  end

  class BeforeActionRedirectionController < ActionController::Base
    before_action :before_action_redirects
    after_action :unreached_after_action

    def show
      @ran_action = true
      render inline: "ran show action"
    end

    def target_of_redirection
      @ran_target_of_redirection = true
      render inline: "ran target_of_redirection action"
    end

    private
      def before_action_redirects
        @ran_action_callback ||= []
        @ran_action_callback << "before_action_redirects"
        redirect_to(action: "target_of_redirection")
      end

      def unreached_after_action
        @ran_action_callback << "unreached_after_action_after_redirection"
      end
  end

  class BeforeActionRedirectionForPrependAfterActionController < BeforeActionRedirectionController
    prepend_after_action :unreached_prepend_after_action_after_redirection

    private
      def unreached_prepend_after_action_after_redirection
        @ran_action_callback << "unreached_prepend_after_action_after_redirection"
      end
  end

  class ConditionalActionCallbackController < ActionController::Base
    def show
      render inline: "ran action"
    end

    def another_action
      render inline: "ran action"
    end

    def show_without_action
      render inline: "ran action without action"
    end

    private
      def ensure_login
        @ran_action_callback ||= []
        @ran_action_callback << "ensure_login"
      end

      def clean_up_tmp
        @ran_action_callback ||= []
        @ran_action_callback << "clean_up_tmp"
      end
  end

  class ConditionalCollectionActionCallbackController < ConditionalActionCallbackController
    before_action :ensure_login, except: [ :show_without_action, :another_action ]
  end

  class OnlyConditionSymController < ConditionalActionCallbackController
    before_action :ensure_login, only: :show
  end

  class ExceptConditionSymController < ConditionalActionCallbackController
    before_action :ensure_login, except: :show_without_action
  end

  class BeforeAndAfterConditionController < ConditionalActionCallbackController
    before_action :ensure_login, only: :show
    after_action  :clean_up_tmp, only: :show
  end

  class OnlyConditionProcController < ConditionalActionCallbackController
    before_action(only: :show) { |c| c.instance_variable_set(:"@ran_proc_action", true) }
  end

  class ExceptConditionProcController < ConditionalActionCallbackController
    before_action(except: :show_without_action) { |c| c.instance_variable_set(:"@ran_proc_action", true) }
  end

  class ConditionalClassActionCallback
    def self.before(controller) controller.instance_variable_set(:"@ran_class_action", true) end
  end

  class OnlyConditionClassController < ConditionalActionCallbackController
    before_action ConditionalClassActionCallback, only: :show
  end

  class ExceptConditionClassController < ConditionalActionCallbackController
    before_action ConditionalClassActionCallback, except: :show_without_action
  end

  class AnomolousYetValidConditionController < ConditionalActionCallbackController
    before_action(ConditionalClassActionCallback, :ensure_login, Proc.new { |c| c.instance_variable_set(:"@ran_proc_action1", true) }, except: :show_without_action) { |c| c.instance_variable_set(:"@ran_proc_action2", true) }
  end

  class OnlyConditionalOptionsActionCallback < ConditionalActionCallbackController
    before_action :ensure_login, only: :index, if: Proc.new { |c| c.instance_variable_set(:"@ran_conditional_index_proc", true) }
  end

  class ConditionalOptionsActionCallback < ConditionalActionCallbackController
    before_action :ensure_login, if: Proc.new { |c| true }
    before_action :clean_up_tmp, if: Proc.new { |c| false }
  end

  class ConditionalOptionsSkipActionCallback < ConditionalActionCallbackController
    before_action :ensure_login
    before_action :clean_up_tmp

    skip_before_action :ensure_login, if: -> { false }
    skip_before_action :clean_up_tmp, if: -> { true }
  end

  class SkipActionCallbackUsingOnlyAndIf < ConditionalActionCallbackController
    before_action :clean_up_tmp
    before_action :ensure_login

    skip_before_action :ensure_login, only: :login, if: -> { false }
    skip_before_action :clean_up_tmp, only: :login, if: -> { true }

    def login
      render plain: "ok"
    end
  end

  class SkipActionCallbackUsingIfAndExcept < ConditionalActionCallbackController
    before_action :clean_up_tmp
    before_action :ensure_login

    skip_before_action :ensure_login, if: -> { false }, except: :login
    skip_before_action :clean_up_tmp, if: -> { true }, except: :login

    def login
      render plain: "ok"
    end
  end

  class ClassController < ConditionalActionCallbackController
    before_action ConditionalClassActionCallback
  end

  class PrependingController < TestController
    prepend_before_action :wonderful_life
    # skip_before_action :fire_flash

    private
      def wonderful_life
        @ran_action_callback ||= []
        @ran_action_callback << "wonderful_life"
      end
  end

  class SkippingAndLimitedController < TestController
    skip_before_action :ensure_login
    before_action :ensure_login, only: :index

    def index
      render plain: "ok"
    end

    def public
      render plain: "ok"
    end
  end

  class SkippingAndReorderingController < TestController
    skip_before_action :ensure_login
    before_action :find_record
    before_action :ensure_login

    def index
      render plain: "ok"
    end

    private
      def find_record
        @ran_action_callback ||= []
        @ran_action_callback << "find_record"
      end
  end

  class ConditionalSkippingController < TestController
    skip_before_action :ensure_login, only: [ :login ]
    skip_after_action  :clean_up,     only: [ :login ]

    before_action :find_user, only: [ :change_password ]

    def login
      render inline: "ran action"
    end

    def change_password
      render inline: "ran action"
    end

    private
      def find_user
        @ran_action_callback ||= []
        @ran_action_callback << "find_user"
      end
  end

  class ConditionalParentOfConditionalSkippingController < ConditionalActionCallbackController
    before_action :conditional_in_parent_before, only: [:show, :another_action]
    after_action  :conditional_in_parent_after, only: [:show, :another_action]

    private

      def conditional_in_parent_before
        @ran_action_callback ||= []
        @ran_action_callback << "conditional_in_parent_before"
      end

      def conditional_in_parent_after
        @ran_action_callback ||= []
        @ran_action_callback << "conditional_in_parent_after"
      end
  end

  class ChildOfConditionalParentController < ConditionalParentOfConditionalSkippingController
    skip_before_action :conditional_in_parent_before, only: :another_action
    skip_after_action  :conditional_in_parent_after, only: :another_action
  end

  class AnotherChildOfConditionalParentController < ConditionalParentOfConditionalSkippingController
    skip_before_action :conditional_in_parent_before, only: :show
  end

  class ProcController < PrependingController
    before_action(proc { |c| c.instance_variable_set(:"@ran_proc_action", true) })
  end

  class ImplicitProcController < PrependingController
    before_action { |c| c.instance_variable_set(:"@ran_proc_action", true) }
  end

  class AuditActionCallback
    def self.before(controller)
      controller.instance_variable_set(:"@was_audited", true)
    end
  end

  class AroundActionCallback
    def before(controller)
      @execution_log = "before"
      controller.class.execution_log << " before around_action_callback " if controller.respond_to? :execution_log
      controller.instance_variable_set(:"@before_ran", true)
    end

    def after(controller)
      controller.instance_variable_set(:"@execution_log", @execution_log + " and after")
      controller.instance_variable_set(:"@after_ran", true)
      controller.class.execution_log << " after around_action_callback " if controller.respond_to? :execution_log
    end

    def around(controller)
      before(controller)
      yield
      after(controller)
    end
  end

  class AppendedAroundActionCallback
    def before(controller)
      controller.class.execution_log << " before appended around_action_callback "
    end

    def after(controller)
      controller.class.execution_log << " after appended around_action_callback "
    end

    def around(controller)
      before(controller)
      yield
      after(controller)
    end
  end

  class AuditController < ActionController::Base
    before_action(AuditActionCallback)

    def show
      render plain: "hello"
    end
  end

  class AroundActionCallbackController < PrependingController
    around_action AroundActionCallback.new
  end

  class BeforeAfterClassActionCallbackController < PrependingController
    begin
      action_callback = AroundActionCallback.new
      before_action action_callback
      after_action action_callback
    end
  end

  class MixedActionCallbackController < PrependingController
    cattr_accessor :execution_log

    def initialize
      @@execution_log = ""
      super()
    end

    before_action { |c| c.class.execution_log << " before proc_action_callback "  }
    prepend_around_action AroundActionCallback.new

    after_action  { |c| c.class.execution_log << " after proc_action_callback " }
    append_around_action AppendedAroundActionCallback.new
  end

  class MixedSpecializationController < ActionController::Base
    class OutOfOrder < StandardError; end

    before_action :first
    before_action :second, only: :foo

    def foo
      render plain: "foo"
    end

    def bar
      render plain: "bar"
    end

    private
      def first
        @first = true
      end

      def second
        raise OutOfOrder unless @first
      end
  end

  class DynamicDispatchController < ActionController::Base
    before_action :choose

    %w(foo bar baz).each do |action|
      define_method(action) { render plain: action }
    end

    private
      def choose
        self.action_name = params[:choose]
      end
  end

  class PrependingBeforeAndAfterController < ActionController::Base
    prepend_before_action :before_all
    prepend_after_action :after_all
    before_action :between_before_all_and_after_all

    def before_all
      @ran_action_callback ||= []
      @ran_action_callback << "before_all"
    end

    def after_all
      @ran_action_callback ||= []
      @ran_action_callback << "after_all"
    end

    def between_before_all_and_after_all
      @ran_action_callback ||= []
      @ran_action_callback << "between_before_all_and_after_all"
    end
    def show
      render plain: "hello"
    end
  end

  class ErrorToRescue < Exception; end

  class RescuingAroundActionCallbackWithBlock
    def around(controller)
      yield
    rescue ErrorToRescue => ex
      controller.__send__ :render, plain: "I rescued this: #{ex.inspect}"
    end
  end

  class RescuedController < ActionController::Base
    around_action RescuingAroundActionCallbackWithBlock.new

    def show
      raise ErrorToRescue.new("Something made the bad noise.")
    end
  end

  class NonYieldingAroundActionCallbackController < ActionController::Base
    before_action :action_callback_one
    around_action :non_yielding_action
    before_action :action_two
    after_action :action_three

    def index
      render inline: "index"
    end

    private

      def action_callback_one
        @action_callbacks ||= []
        @action_callbacks << "action_callback_one"
      end

      def action_two
        @action_callbacks << "action_two"
      end

      def non_yielding_action
        @action_callbacks << "it didn't yield"
      end

      def action_three
        @action_callbacks << "action_three"
      end
  end

  class ImplicitActionsController < ActionController::Base
    before_action :find_only, only: :edit
    before_action :find_except, except: :edit

    private

      def find_only
        @only = "Only"
      end

      def find_except
        @except = "Except"
      end
  end

  def test_non_yielding_around_actions_do_not_raise
    controller = NonYieldingAroundActionCallbackController.new
    assert_nothing_raised do
      test_process(controller, "index")
    end
  end

  def test_after_actions_are_not_run_if_around_action_does_not_yield
    controller = NonYieldingAroundActionCallbackController.new
    test_process(controller, "index")
    assert_equal ["action_callback_one", "it didn't yield"], controller.instance_variable_get(:@action_callbacks)
  end

  def test_added_action_to_inheritance_graph
    assert_equal [ :ensure_login ], TestController.before_actions
  end

  def test_base_class_in_isolation
    assert_equal [ ], ActionController::Base.before_actions
  end

  def test_prepending_action
    assert_equal [ :wonderful_life, :ensure_login ], PrependingController.before_actions
  end

  def test_running_actions
    test_process(PrependingController)
    assert_equal %w( wonderful_life ensure_login ),
      @controller.instance_variable_get(:@ran_action_callback)
  end

  def test_running_actions_with_proc
    test_process(ProcController)
    assert @controller.instance_variable_get(:@ran_proc_action)
  end

  def test_running_actions_with_implicit_proc
    test_process(ImplicitProcController)
    assert @controller.instance_variable_get(:@ran_proc_action)
  end

  def test_running_actions_with_class
    test_process(AuditController)
    assert @controller.instance_variable_get(:@was_audited)
  end

  def test_running_anomalous_yet_valid_condition_actions
    test_process(AnomolousYetValidConditionController)
    assert_equal %w( ensure_login ), @controller.instance_variable_get(:@ran_action_callback)
    assert @controller.instance_variable_get(:@ran_class_action)
    assert @controller.instance_variable_get(:@ran_proc_action1)
    assert @controller.instance_variable_get(:@ran_proc_action2)

    test_process(AnomolousYetValidConditionController, "show_without_action")
    assert_not @controller.instance_variable_defined?(:@ran_action_callback)
    assert_not @controller.instance_variable_defined?(:@ran_class_action)
    assert_not @controller.instance_variable_defined?(:@ran_proc_action1)
    assert_not @controller.instance_variable_defined?(:@ran_proc_action2)
  end

  def test_running_conditional_options
    test_process(ConditionalOptionsActionCallback)
    assert_equal %w( ensure_login ), @controller.instance_variable_get(:@ran_action_callback)
  end

  def test_running_conditional_skip_options
    test_process(ConditionalOptionsSkipActionCallback)
    assert_equal %w( ensure_login ), @controller.instance_variable_get(:@ran_action_callback)
  end

  def test_if_is_ignored_when_used_with_only
    test_process(SkipActionCallbackUsingOnlyAndIf, "login")
    assert_not @controller.instance_variable_defined?(:@ran_action_callback)
  end

  def test_except_is_ignored_when_used_with_if
    test_process(SkipActionCallbackUsingIfAndExcept, "login")
    assert_equal %w(ensure_login), @controller.instance_variable_get(:@ran_action_callback)
  end

  def test_skipping_class_actions
    test_process(ClassController)
    assert_equal true, @controller.instance_variable_get(:@ran_class_action)

    skipping_class_controller = Class.new(ClassController) do
      skip_before_action ConditionalClassActionCallback
    end

    test_process(skipping_class_controller)
    assert_not @controller.instance_variable_defined?(:@ran_class_action)
  end

  def test_running_collection_condition_actions
    test_process(ConditionalCollectionActionCallbackController)
    assert_equal %w( ensure_login ), @controller.instance_variable_get(:@ran_action_callback)
    test_process(ConditionalCollectionActionCallbackController, "show_without_action")
    assert_not @controller.instance_variable_defined?(:@ran_action_callback)
    test_process(ConditionalCollectionActionCallbackController, "another_action")
    assert_not @controller.instance_variable_defined?(:@ran_action_callback)
  end

  def test_running_only_condition_actions
    test_process(OnlyConditionSymController)
    assert_equal %w( ensure_login ), @controller.instance_variable_get(:@ran_action_callback)
    test_process(OnlyConditionSymController, "show_without_action")
    assert_not @controller.instance_variable_defined?(:@ran_action_callback)

    test_process(OnlyConditionProcController)
    assert @controller.instance_variable_get(:@ran_proc_action)
    test_process(OnlyConditionProcController, "show_without_action")
    assert_not @controller.instance_variable_defined?(:@ran_proc_action)

    test_process(OnlyConditionClassController)
    assert @controller.instance_variable_get(:@ran_class_action)
    test_process(OnlyConditionClassController, "show_without_action")
    assert_not @controller.instance_variable_defined?(:@ran_class_action)
  end

  def test_running_except_condition_actions
    test_process(ExceptConditionSymController)
    assert_equal %w( ensure_login ), @controller.instance_variable_get(:@ran_action_callback)
    test_process(ExceptConditionSymController, "show_without_action")
    assert_not @controller.instance_variable_defined?(:@ran_action_callback)

    test_process(ExceptConditionProcController)
    assert @controller.instance_variable_get(:@ran_proc_action)
    test_process(ExceptConditionProcController, "show_without_action")
    assert_not @controller.instance_variable_defined?(:@ran_proc_action)

    test_process(ExceptConditionClassController)
    assert @controller.instance_variable_get(:@ran_class_action)
    test_process(ExceptConditionClassController, "show_without_action")
    assert_not @controller.instance_variable_defined?(:@ran_class_action)
  end

  def test_running_only_condition_and_conditional_options
    test_process(OnlyConditionalOptionsActionCallback, "show")
    assert_not @controller.instance_variable_defined?(:@ran_conditional_index_proc)
  end

  def test_running_before_and_after_condition_actions
    test_process(BeforeAndAfterConditionController)
    assert_equal %w( ensure_login clean_up_tmp), @controller.instance_variable_get(:@ran_action_callback)
    test_process(BeforeAndAfterConditionController, "show_without_action")
    assert_not @controller.instance_variable_defined?(:@ran_action_callback)
  end

  def test_around_action
    test_process(AroundActionCallbackController)
    assert @controller.instance_variable_get(:@before_ran)
    assert @controller.instance_variable_get(:@after_ran)
  end

  def test_before_after_class_action
    test_process(BeforeAfterClassActionCallbackController)
    assert @controller.instance_variable_get(:@before_ran)
    assert @controller.instance_variable_get(:@after_ran)
  end

  def test_having_properties_in_around_action
    test_process(AroundActionCallbackController)
    assert_equal "before and after", @controller.instance_variable_get(:@execution_log)
  end

  def test_prepending_and_appending_around_action
    test_process(MixedActionCallbackController)
    assert_equal " before around_action_callback  before proc_action_callback  before appended around_action_callback " \
                 " after appended around_action_callback  after proc_action_callback  after around_action_callback ",
                 MixedActionCallbackController.execution_log
  end

  def test_rendering_breaks_actioning_chain
    response = test_process(RenderingController)
    assert_equal "something else", response.body
    assert_not @controller.instance_variable_defined?(:@ran_action)
  end

  def test_before_action_rendering_breaks_actioning_chain_for_after_action
    test_process(RenderingController)
    assert_equal %w( before_action_rendering ), @controller.instance_variable_get(:@ran_action_callback)
    assert_not @controller.instance_variable_defined?(:@ran_action)
  end

  def test_before_action_redirects_breaks_actioning_chain_for_after_action
    test_process(BeforeActionRedirectionController)
    assert_response :redirect
    assert_equal "http://test.host/action_callback_test/before_action_redirection/target_of_redirection", redirect_to_url
    assert_equal %w( before_action_redirects ), @controller.instance_variable_get(:@ran_action_callback)
  end

  def test_before_action_rendering_breaks_actioning_chain_for_preprend_after_action
    test_process(RenderingForPrependAfterActionController)
    assert_equal %w( before_action_rendering ), @controller.instance_variable_get(:@ran_action_callback)
    assert_not @controller.instance_variable_defined?(:@ran_action)
  end

  def test_before_action_redirects_breaks_actioning_chain_for_preprend_after_action
    test_process(BeforeActionRedirectionForPrependAfterActionController)
    assert_response :redirect
    assert_equal "http://test.host/action_callback_test/before_action_redirection_for_prepend_after_action/target_of_redirection", redirect_to_url
    assert_equal %w( before_action_redirects ), @controller.instance_variable_get(:@ran_action_callback)
  end

  def test_actions_with_mixed_specialization_run_in_order
    assert_nothing_raised do
      response = test_process(MixedSpecializationController, "bar")
      assert_equal "bar", response.body
    end

    assert_nothing_raised do
      response = test_process(MixedSpecializationController, "foo")
      assert_equal "foo", response.body
    end
  end

  def test_dynamic_dispatch
    %w(foo bar baz).each do |action|
      @request.query_parameters[:choose] = action
      response = DynamicDispatchController.action(action).call(@request.env).last
      assert_equal action, response.body
    end
  end

  def test_running_prepended_before_and_after_action
    test_process(PrependingBeforeAndAfterController)
    assert_equal %w( before_all between_before_all_and_after_all after_all ), @controller.instance_variable_get(:@ran_action_callback)
  end

  def test_skipping_and_limiting_controller
    test_process(SkippingAndLimitedController, "index")
    assert_equal %w( ensure_login ), @controller.instance_variable_get(:@ran_action_callback)
    test_process(SkippingAndLimitedController, "public")
    assert_not @controller.instance_variable_defined?(:@ran_action_callback)
  end

  def test_skipping_and_reordering_controller
    test_process(SkippingAndReorderingController, "index")
    assert_equal %w( find_record ensure_login ), @controller.instance_variable_get(:@ran_action_callback)
  end

  def test_conditional_skipping_of_actions
    test_process(ConditionalSkippingController, "login")
    assert_not @controller.instance_variable_defined?(:@ran_action_callback)
    test_process(ConditionalSkippingController, "change_password")
    assert_equal %w( ensure_login find_user ), @controller.instance_variable_get(:@ran_action_callback)

    test_process(ConditionalSkippingController, "login")
    assert !@controller.instance_variable_defined?("@ran_after_action")
    test_process(ConditionalSkippingController, "change_password")
    assert_equal %w( clean_up ), @controller.instance_variable_get("@ran_after_action")
  end

  def test_conditional_skipping_of_actions_when_parent_action_is_also_conditional
    test_process(ChildOfConditionalParentController)
    assert_equal %w( conditional_in_parent_before conditional_in_parent_after ), @controller.instance_variable_get(:@ran_action_callback)
    test_process(ChildOfConditionalParentController, "another_action")
    assert_not @controller.instance_variable_defined?(:@ran_action_callback)
  end

  def test_condition_skipping_of_actions_when_siblings_also_have_conditions
    test_process(ChildOfConditionalParentController)
    assert_equal %w( conditional_in_parent_before conditional_in_parent_after ), @controller.instance_variable_get(:@ran_action_callback)
    test_process(AnotherChildOfConditionalParentController)
    assert_equal %w( conditional_in_parent_after ), @controller.instance_variable_get(:@ran_action_callback)
    test_process(ChildOfConditionalParentController)
    assert_equal %w( conditional_in_parent_before conditional_in_parent_after ), @controller.instance_variable_get(:@ran_action_callback)
  end

  def test_changing_the_requirements
    test_process(ChangingTheRequirementsController, "go_wild")
    assert_not @controller.instance_variable_defined?(:@ran_action_callback)
  end

  def test_a_rescuing_around_action
    response = nil
    assert_nothing_raised do
      response = test_process(RescuedController)
    end

    assert response.successful?
    assert_equal("I rescued this: #<ActionCallbackTest::ErrorToRescue: Something made the bad noise.>", response.body)
  end

  def test_actions_obey_only_and_except_for_implicit_actions
    test_process(ImplicitActionsController, "show")
    assert_equal "Except", @controller.instance_variable_get(:@except)
    assert_not @controller.instance_variable_defined?(:@only)
    assert_equal "show", response.body

    test_process(ImplicitActionsController, "edit")
    assert_equal "Only", @controller.instance_variable_get(:@only)
    assert_not @controller.instance_variable_defined?(:@except)
    assert_equal "edit", response.body
  end

  private
    def test_process(controller, action = "show")
      @controller = controller.is_a?(Class) ? controller.new : controller

      process(action)
    end
end

class PostsController < ActionController::Base
  module AroundExceptions
    class Error < StandardError ; end
    class Before < Error ; end
    class After < Error ; end
  end
  include AroundExceptions

  class DefaultActionCallback
    include AroundExceptions
  end

  module_eval %w(raises_before raises_after raises_both no_raise no_action).map { |action| "def #{action}; default_action end" }.join("\n")

  private
    def default_action
      render inline: "#{action_name} called"
    end
end

class ControllerWithSymbolAsActionCallback < PostsController
  around_action :raise_before, only: :raises_before
  around_action :raise_after, only: :raises_after
  around_action :without_exception, only: :no_raise

  private
    def raise_before
      raise Before
      yield
    end

    def raise_after
      yield
      raise After
    end

    def without_exception
      # Do stuff...
      wtf = 1 + 1

      yield

      # Do stuff...
      wtf += 1
    end
end

class ControllerWithActionCallbackClass < PostsController
  class YieldingActionCallback < DefaultActionCallback
    def self.around(controller)
      yield
      raise After
    end
  end

  around_action YieldingActionCallback, only: :raises_after
end

class ControllerWithActionCallbackInstance < PostsController
  class YieldingActionCallback < DefaultActionCallback
    def around(controller)
      yield
      raise After
    end
  end

  around_action YieldingActionCallback.new, only: :raises_after
end

class ControllerWithProcActionCallback < PostsController
  around_action(only: :no_raise) do |c, b|
    c.instance_variable_set(:"@before", true)
    b.call
    c.instance_variable_set(:"@after", true)
  end
end

class ControllerWithNestedActionCallbacks < ControllerWithSymbolAsActionCallback
  around_action :raise_before, :raise_after, :without_exception, only: :raises_both
end

class ControllerWithAllTypesOfActionCallbacks < PostsController
  before_action :before
  around_action :around
  after_action :after
  around_action :around_again

  private
    def before
      @ran_action_callback ||= []
      @ran_action_callback << "before"
    end

    def around
      @ran_action_callback << "around (before yield)"
      yield
      @ran_action_callback << "around (after yield)"
    end

    def after
      @ran_action_callback << "after"
    end

    def around_again
      @ran_action_callback << "around_again (before yield)"
      yield
      @ran_action_callback << "around_again (after yield)"
    end
end

class ControllerWithTwoLessActionCallbacks < ControllerWithAllTypesOfActionCallbacks
  skip_around_action :around_again
  skip_after_action :after
end

class YieldingAroundActionCallbacksTest < ActionController::TestCase
  include PostsController::AroundExceptions

  def test_base
    controller = PostsController
    assert_nothing_raised { test_process(controller, "no_raise") }
    assert_nothing_raised { test_process(controller, "raises_before") }
    assert_nothing_raised { test_process(controller, "raises_after") }
    assert_nothing_raised { test_process(controller, "no_action") }
  end

  def test_with_symbol
    controller = ControllerWithSymbolAsActionCallback
    assert_nothing_raised { test_process(controller, "no_raise") }
    assert_raise(Before) { test_process(controller, "raises_before") }
    assert_raise(After) { test_process(controller, "raises_after") }
    assert_nothing_raised { test_process(controller, "no_raise") }
  end

  def test_with_class
    controller = ControllerWithActionCallbackClass
    assert_nothing_raised { test_process(controller, "no_raise") }
    assert_raise(After) { test_process(controller, "raises_after") }
  end

  def test_with_instance
    controller = ControllerWithActionCallbackInstance
    assert_nothing_raised { test_process(controller, "no_raise") }
    assert_raise(After) { test_process(controller, "raises_after") }
  end

  def test_with_proc
    test_process(ControllerWithProcActionCallback, "no_raise")
    assert @controller.instance_variable_get(:@before)
    assert @controller.instance_variable_get(:@after)
  end

  def test_nested_actions
    controller = ControllerWithNestedActionCallbacks
    assert_nothing_raised do
      begin
        test_process(controller, "raises_both")
      rescue Before, After
      end
    end
    assert_raise Before do
      begin
        test_process(controller, "raises_both")
      rescue After
      end
    end
  end

  def test_action_order_with_all_action_types
    test_process(ControllerWithAllTypesOfActionCallbacks, "no_raise")
    assert_equal "before around (before yield) around_again (before yield) around_again (after yield) after around (after yield)", @controller.instance_variable_get(:@ran_action_callback).join(" ")
  end

  def test_action_order_with_skip_action_method
    test_process(ControllerWithTwoLessActionCallbacks, "no_raise")
    assert_equal "before around (before yield) around (after yield)", @controller.instance_variable_get(:@ran_action_callback).join(" ")
  end

  def test_first_action_in_multiple_before_action_chain_halts
    controller = ::ActionCallbackTest::TestMultipleActionCallbacksController.new
    response = test_process(controller, "fail_1")
    assert_equal "", response.body
    assert_equal 1, controller.instance_variable_get(:@try)
  end

  def test_second_action_in_multiple_before_action_chain_halts
    controller = ::ActionCallbackTest::TestMultipleActionCallbacksController.new
    response = test_process(controller, "fail_2")
    assert_equal "", response.body
    assert_equal 2, controller.instance_variable_get(:@try)
  end

  def test_last_action_in_multiple_before_action_chain_halts
    controller = ::ActionCallbackTest::TestMultipleActionCallbacksController.new
    response = test_process(controller, "fail_3")
    assert_equal "", response.body
    assert_equal 3, controller.instance_variable_get(:@try)
  end

  private
    def test_process(controller, action = "show")
      @controller = controller.is_a?(Class) ? controller.new : controller
      process(action)
    end
end
