require File.dirname(__FILE__) + '/../abstract_unit'

class FilterTest < Test::Unit::TestCase
  class TestController < ActionController::Base
    before_filter :ensure_login
    after_filter  :clean_up

    def show
      render :inline => "ran action"
    end

    private
      def ensure_login
        @ran_filter ||= []
        @ran_filter << "ensure_login"
      end

      def clean_up
        @ran_after_filter ||= []
        @ran_after_filter << "clean_up"
      end
  end

  class ChangingTheRequirementsController < TestController
    before_filter :ensure_login, :except => [:go_wild]

    def go_wild
      render :text => "gobble"
    end
  end

  class TestMultipleFiltersController < ActionController::Base
    before_filter :try_1
    before_filter :try_2
    before_filter :try_3

    (1..3).each do |i|
      define_method "fail_#{i}" do
        render :text => i.to_s
      end
    end

    protected
    (1..3).each do |i|
      define_method "try_#{i}" do
        instance_variable_set :@try, i
        action_name != "fail_#{i}"
      end
    end
  end

  class RenderingController < ActionController::Base
    before_filter :render_something_else

    def show
      @ran_action = true
      render :inline => "ran action"
    end

    private
      def render_something_else
        render :inline => "something else"
      end
  end

  class ConditionalFilterController < ActionController::Base
    def show
      render :inline => "ran action"
    end

    def another_action
      render :inline => "ran action"
    end

    def show_without_filter
      render :inline => "ran action without filter"
    end

    private
      def ensure_login
        @ran_filter ||= []
        @ran_filter << "ensure_login"
      end

      def clean_up_tmp
        @ran_filter ||= []
        @ran_filter << "clean_up_tmp"
      end

      def rescue_action(e) raise(e) end
  end

  class ConditionalCollectionFilterController < ConditionalFilterController
    before_filter :ensure_login, :except => [ :show_without_filter, :another_action ]
  end

  class OnlyConditionSymController < ConditionalFilterController
    before_filter :ensure_login, :only => :show
  end

  class ExceptConditionSymController < ConditionalFilterController
    before_filter :ensure_login, :except => :show_without_filter
  end

  class BeforeAndAfterConditionController < ConditionalFilterController
    before_filter :ensure_login, :only => :show
    after_filter  :clean_up_tmp, :only => :show
  end

  class OnlyConditionProcController < ConditionalFilterController
    before_filter(:only => :show) {|c| c.assigns["ran_proc_filter"] = true }
  end

  class ExceptConditionProcController < ConditionalFilterController
    before_filter(:except => :show_without_filter) {|c| c.assigns["ran_proc_filter"] = true }
  end

  class ConditionalClassFilter
    def self.filter(controller) controller.assigns["ran_class_filter"] = true end
  end

  class OnlyConditionClassController < ConditionalFilterController
    before_filter ConditionalClassFilter, :only => :show
  end

  class ExceptConditionClassController < ConditionalFilterController
    before_filter ConditionalClassFilter, :except => :show_without_filter
  end

  class AnomolousYetValidConditionController < ConditionalFilterController
    before_filter(ConditionalClassFilter, :ensure_login, Proc.new {|c| c.assigns["ran_proc_filter1"] = true }, :except => :show_without_filter) { |c| c.assigns["ran_proc_filter2"] = true}
  end

  class EmptyFilterChainController < TestController
    self.filter_chain.clear
    def show
      @action_executed = true
      render :text => "yawp!"
    end
  end

  class PrependingController < TestController
    prepend_before_filter :wonderful_life
    # skip_before_filter :fire_flash

    private
      def wonderful_life
        @ran_filter ||= []
        @ran_filter << "wonderful_life"
      end
  end

  class ConditionalSkippingController < TestController
    skip_before_filter :ensure_login, :only => [ :login ]
    skip_after_filter  :clean_up,     :only => [ :login ]

    before_filter :find_user, :only => [ :change_password ]

    def login
      render :inline => "ran action"
    end

    def change_password
      render :inline => "ran action"
    end

    protected
      def find_user
        @ran_filter ||= []
        @ran_filter << "find_user"
      end
  end

  class ConditionalParentOfConditionalSkippingController < ConditionalFilterController
    before_filter :conditional_in_parent, :only => [:show, :another_action]
    after_filter  :conditional_in_parent, :only => [:show, :another_action]

    private

      def conditional_in_parent
        @ran_filter ||= []
        @ran_filter << 'conditional_in_parent'
      end
  end

  class ChildOfConditionalParentController < ConditionalParentOfConditionalSkippingController
    skip_before_filter :conditional_in_parent, :only => :another_action
    skip_after_filter  :conditional_in_parent, :only => :another_action
  end

  class AnotherChildOfConditionalParentController < ConditionalParentOfConditionalSkippingController
    skip_before_filter :conditional_in_parent, :only => :show
  end

  class ProcController < PrependingController
    before_filter(proc { |c| c.assigns["ran_proc_filter"] = true })
  end

  class ImplicitProcController < PrependingController
    before_filter { |c| c.assigns["ran_proc_filter"] = true }
  end

  class AuditFilter
    def self.filter(controller)
      controller.assigns["was_audited"] = true
    end
  end

  class AroundFilter
    def before(controller)
      @execution_log = "before"
      controller.class.execution_log << " before aroundfilter " if controller.respond_to? :execution_log
      controller.assigns["before_ran"] = true
    end

    def after(controller)
      controller.assigns["execution_log"] = @execution_log + " and after"
      controller.assigns["after_ran"] = true
      controller.class.execution_log << " after aroundfilter " if controller.respond_to? :execution_log
    end
  end

  class AppendedAroundFilter
    def before(controller)
      controller.class.execution_log << " before appended aroundfilter "
    end

    def after(controller)
      controller.class.execution_log << " after appended aroundfilter "
    end
  end

  class AuditController < ActionController::Base
    before_filter(AuditFilter)

    def show
      render_text "hello"
    end
  end

  class AroundFilterController < PrependingController
    around_filter AroundFilter.new
  end

  class BeforeAfterClassFilterController < PrependingController
    begin
      filter = AroundFilter.new
      before_filter filter
      after_filter filter
    end
  end

  class MixedFilterController < PrependingController
    cattr_accessor :execution_log

    def initialize
      @@execution_log = ""
    end

    before_filter { |c| c.class.execution_log << " before procfilter "  }
    prepend_around_filter AroundFilter.new

    after_filter  { |c| c.class.execution_log << " after procfilter " }
    append_around_filter AppendedAroundFilter.new
  end

  class MixedSpecializationController < ActionController::Base
    class OutOfOrder < StandardError; end

    before_filter :first
    before_filter :second, :only => :foo

    def foo
      render_text 'foo'
    end

    def bar
      render_text 'bar'
    end

    protected
      def first
        @first = true
      end

      def second
        raise OutOfOrder unless @first
      end
  end

  class DynamicDispatchController < ActionController::Base
    before_filter :choose

    %w(foo bar baz).each do |action|
      define_method(action) { render :text => action }
    end

    private
      def choose
        self.action_name = params[:choose]
      end
  end

  class PrependingBeforeAndAfterController < ActionController::Base
    prepend_before_filter :before_all
    prepend_after_filter :after_all
    before_filter :between_before_all_and_after_all

    def before_all
      @ran_filter ||= []
      @ran_filter << 'before_all'
    end

    def after_all
      @ran_filter ||= []
      @ran_filter << 'after_all'
    end

    def between_before_all_and_after_all
      @ran_filter ||= []
      @ran_filter << 'between_before_all_and_after_all'
    end
    def show
      render :text => 'hello'
    end
  end

  class NonYieldingAroundFilterController < ActionController::Base

    before_filter :filter_one
    around_filter :non_yielding_filter
    before_filter :filter_two
    after_filter :filter_three

    def index
      render :inline => "index"
    end

    #make sure the controller complains
    def rescue_action(e); raise e; end

    private

      def filter_one
        @filters  ||= []
        @filters  << "filter_one"
      end

      def filter_two
        @filters  << "filter_two"
      end

      def non_yielding_filter
        @filters  << "zomg it didn't yield"
        @filter_return_value
      end

      def filter_three
        @filters  << "filter_three"
      end

  end

  def test_non_yielding_around_filters_not_returning_false_do_not_raise
    controller = NonYieldingAroundFilterController.new
    controller.instance_variable_set "@filter_return_value", true
    assert_nothing_raised do
      test_process(controller, "index")
    end
  end

  def test_non_yielding_around_filters_returning_false_do_not_raise
    controller = NonYieldingAroundFilterController.new
    controller.instance_variable_set "@filter_return_value", false
    assert_nothing_raised do
      test_process(controller, "index")
    end
  end

  def test_after_filters_are_not_run_if_around_filter_returns_false
    controller = NonYieldingAroundFilterController.new
    controller.instance_variable_set "@filter_return_value", false
    test_process(controller, "index")
    assert_equal ["filter_one", "zomg it didn't yield"], controller.assigns['filters']
  end

  def test_after_filters_are_not_run_if_around_filter_does_not_yield
    controller = NonYieldingAroundFilterController.new
    controller.instance_variable_set "@filter_return_value", true
    test_process(controller, "index")
    assert_equal ["filter_one", "zomg it didn't yield"], controller.assigns['filters']
  end

  def test_empty_filter_chain
    assert_equal 0, EmptyFilterChainController.filter_chain.size
    assert test_process(EmptyFilterChainController).template.assigns['action_executed']
  end

  def test_added_filter_to_inheritance_graph
    assert_equal [ :ensure_login ], TestController.before_filters
  end

  def test_base_class_in_isolation
    assert_equal [ ], ActionController::Base.before_filters
  end

  def test_prepending_filter
    assert_equal [ :wonderful_life, :ensure_login ], PrependingController.before_filters
  end

  def test_running_filters
    assert_equal %w( wonderful_life ensure_login ), test_process(PrependingController).template.assigns["ran_filter"]
  end

  def test_running_filters_with_proc
    assert test_process(ProcController).template.assigns["ran_proc_filter"]
  end

  def test_running_filters_with_implicit_proc
    assert test_process(ImplicitProcController).template.assigns["ran_proc_filter"]
  end

  def test_running_filters_with_class
    assert test_process(AuditController).template.assigns["was_audited"]
  end

  def test_running_anomolous_yet_valid_condition_filters
    response = test_process(AnomolousYetValidConditionController)
    assert_equal %w( ensure_login ), response.template.assigns["ran_filter"]
    assert response.template.assigns["ran_class_filter"]
    assert response.template.assigns["ran_proc_filter1"]
    assert response.template.assigns["ran_proc_filter2"]

    response = test_process(AnomolousYetValidConditionController, "show_without_filter")
    assert_equal nil, response.template.assigns["ran_filter"]
    assert !response.template.assigns["ran_class_filter"]
    assert !response.template.assigns["ran_proc_filter1"]
    assert !response.template.assigns["ran_proc_filter2"]
  end

  def test_running_collection_condition_filters
    assert_equal %w( ensure_login ), test_process(ConditionalCollectionFilterController).template.assigns["ran_filter"]
    assert_equal nil, test_process(ConditionalCollectionFilterController, "show_without_filter").template.assigns["ran_filter"]
    assert_equal nil, test_process(ConditionalCollectionFilterController, "another_action").template.assigns["ran_filter"]
  end

  def test_running_only_condition_filters
    assert_equal %w( ensure_login ), test_process(OnlyConditionSymController).template.assigns["ran_filter"]
    assert_equal nil, test_process(OnlyConditionSymController, "show_without_filter").template.assigns["ran_filter"]

    assert test_process(OnlyConditionProcController).template.assigns["ran_proc_filter"]
    assert !test_process(OnlyConditionProcController, "show_without_filter").template.assigns["ran_proc_filter"]

    assert test_process(OnlyConditionClassController).template.assigns["ran_class_filter"]
    assert !test_process(OnlyConditionClassController, "show_without_filter").template.assigns["ran_class_filter"]
  end

  def test_running_except_condition_filters
    assert_equal %w( ensure_login ), test_process(ExceptConditionSymController).template.assigns["ran_filter"]
    assert_equal nil, test_process(ExceptConditionSymController, "show_without_filter").template.assigns["ran_filter"]

    assert test_process(ExceptConditionProcController).template.assigns["ran_proc_filter"]
    assert !test_process(ExceptConditionProcController, "show_without_filter").template.assigns["ran_proc_filter"]

    assert test_process(ExceptConditionClassController).template.assigns["ran_class_filter"]
    assert !test_process(ExceptConditionClassController, "show_without_filter").template.assigns["ran_class_filter"]
  end

  def test_running_before_and_after_condition_filters
    assert_equal %w( ensure_login clean_up_tmp), test_process(BeforeAndAfterConditionController).template.assigns["ran_filter"]
    assert_equal nil, test_process(BeforeAndAfterConditionController, "show_without_filter").template.assigns["ran_filter"]
  end

  def test_bad_filter
    bad_filter_controller = Class.new(ActionController::Base)
    assert_raises(ActionController::ActionControllerError) do
      bad_filter_controller.before_filter 2
    end
  end

  def test_around_filter
    controller = test_process(AroundFilterController)
    assert controller.template.assigns["before_ran"]
    assert controller.template.assigns["after_ran"]
  end

  def test_before_after_class_filter
    controller = test_process(BeforeAfterClassFilterController)
    assert controller.template.assigns["before_ran"]
    assert controller.template.assigns["after_ran"]
  end

  def test_having_properties_in_around_filter
    controller = test_process(AroundFilterController)
    assert_equal "before and after", controller.template.assigns["execution_log"]
  end

  def test_prepending_and_appending_around_filter
    controller = test_process(MixedFilterController)
    assert_equal " before aroundfilter  before procfilter  before appended aroundfilter " +
                 " after appended aroundfilter  after aroundfilter  after procfilter ",
                 MixedFilterController.execution_log
  end

  def test_rendering_breaks_filtering_chain
    response = test_process(RenderingController)
    assert_equal "something else", response.body
    assert !response.template.assigns["ran_action"]
  end

  def test_filters_with_mixed_specialization_run_in_order
    assert_nothing_raised do
      response = test_process(MixedSpecializationController, 'bar')
      assert_equal 'bar', response.body
    end

    assert_nothing_raised do
      response = test_process(MixedSpecializationController, 'foo')
      assert_equal 'foo', response.body
    end
  end

  def test_dynamic_dispatch
    %w(foo bar baz).each do |action|
      request = ActionController::TestRequest.new
      request.query_parameters[:choose] = action
      response = DynamicDispatchController.process(request, ActionController::TestResponse.new)
      assert_equal action, response.body
    end
  end

  def test_running_prepended_before_and_after_filter
    assert_equal 3, PrependingBeforeAndAfterController.filter_chain.length
    response = test_process(PrependingBeforeAndAfterController)
    assert_equal %w( before_all between_before_all_and_after_all after_all ), response.template.assigns["ran_filter"]
  end

  def test_conditional_skipping_of_filters
    assert_nil test_process(ConditionalSkippingController, "login").template.assigns["ran_filter"]
    assert_equal %w( ensure_login find_user ), test_process(ConditionalSkippingController, "change_password").template.assigns["ran_filter"]

    assert_nil test_process(ConditionalSkippingController, "login").template.controller.instance_variable_get("@ran_after_filter")
    assert_equal %w( clean_up ), test_process(ConditionalSkippingController, "change_password").template.controller.instance_variable_get("@ran_after_filter")
  end

  def test_conditional_skipping_of_filters_when_parent_filter_is_also_conditional
    assert_equal %w( conditional_in_parent conditional_in_parent ), test_process(ChildOfConditionalParentController).template.assigns['ran_filter']
    assert_nil test_process(ChildOfConditionalParentController, 'another_action').template.assigns['ran_filter']
  end

  def test_condition_skipping_of_filters_when_siblings_also_have_conditions
    assert_equal %w( conditional_in_parent conditional_in_parent ), test_process(ChildOfConditionalParentController).template.assigns['ran_filter'], "1"
    assert_equal nil, test_process(AnotherChildOfConditionalParentController).template.assigns['ran_filter']
    assert_equal %w( conditional_in_parent conditional_in_parent ), test_process(ChildOfConditionalParentController).template.assigns['ran_filter']
  end

  def test_changing_the_requirements
    assert_equal nil, test_process(ChangingTheRequirementsController, "go_wild").template.assigns['ran_filter']
  end

  private
    def test_process(controller, action = "show")
      request = ActionController::TestRequest.new
      request.action = action
      controller.process(request, ActionController::TestResponse.new)
    end
end



class PostsController < ActionController::Base
  def rescue_action(e); raise e; end

  module AroundExceptions
    class Error < StandardError ; end
    class Before < Error ; end
    class After < Error ; end
  end
  include AroundExceptions

  class DefaultFilter
    include AroundExceptions
  end

  module_eval %w(raises_before raises_after raises_both no_raise no_filter).map { |action| "def #{action}; default_action end" }.join("\n")

  private
    def default_action
      render :inline => "#{action_name} called"
    end
end

class ControllerWithSymbolAsFilter < PostsController
  around_filter :raise_before, :only => :raises_before
  around_filter :raise_after, :only => :raises_after
  around_filter :without_exception, :only => :no_raise

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
      1 + 1

      yield

      # Do stuff...
      1 + 1
    end
end

class ControllerWithFilterClass < PostsController
  class YieldingFilter < DefaultFilter
    def self.filter(controller)
      yield
      raise After
    end
  end

  around_filter YieldingFilter, :only => :raises_after
end

class ControllerWithFilterInstance < PostsController
  class YieldingFilter < DefaultFilter
    def filter(controller)
      yield
      raise After
    end
  end

  around_filter YieldingFilter.new, :only => :raises_after
end

class ControllerWithFilterMethod < PostsController
  class YieldingFilter < DefaultFilter
    def filter(controller)
      yield
      raise After
    end
  end

  around_filter YieldingFilter.new.method(:filter), :only => :raises_after
end

class ControllerWithProcFilter < PostsController
  around_filter(:only => :no_raise) do |c,b|
    c.assigns['before'] = true
    b.call
    c.assigns['after'] = true
  end
end

class ControllerWithWrongFilterType < PostsController
  around_filter lambda { yield }, :only => :no_raise
end

class ControllerWithNestedFilters < ControllerWithSymbolAsFilter
  around_filter :raise_before, :raise_after, :without_exception, :only => :raises_both
end

class ControllerWithAllTypesOfFilters < PostsController
  before_filter :before
  around_filter :around
  after_filter :after
  around_filter :around_again

  private
  def before
    @ran_filter ||= []
    @ran_filter << 'before'
  end

  def around
    @ran_filter << 'around (before yield)'
    yield
    @ran_filter << 'around (after yield)'
  end

  def after
    @ran_filter << 'after'
  end

  def around_again
    @ran_filter << 'around_again (before yield)'
    yield
    @ran_filter << 'around_again (after yield)'
  end
end

class ControllerWithTwoLessFilters < ControllerWithAllTypesOfFilters
  skip_filter :around_again
  skip_filter :after
end

class YieldingAroundFiltersTest < Test::Unit::TestCase
  include PostsController::AroundExceptions

  def test_filters_registering
    assert_equal 1, ControllerWithFilterMethod.filter_chain.size
    assert_equal 1, ControllerWithFilterClass.filter_chain.size
    assert_equal 1, ControllerWithFilterInstance.filter_chain.size
    assert_equal 3, ControllerWithSymbolAsFilter.filter_chain.size
    assert_equal 1, ControllerWithWrongFilterType.filter_chain.size
    assert_equal 6, ControllerWithNestedFilters.filter_chain.size
    assert_equal 4, ControllerWithAllTypesOfFilters.filter_chain.size
  end

  def test_wrong_filter_type
    assert_raise(ActionController::ActionControllerError) do
      test_process(ControllerWithWrongFilterType,'no_raise')
    end
  end

  def test_base
    controller = PostsController
    assert_nothing_raised { test_process(controller,'no_raise') }
    assert_nothing_raised { test_process(controller,'raises_before') }
    assert_nothing_raised { test_process(controller,'raises_after') }
    assert_nothing_raised { test_process(controller,'no_filter') }
  end

  def test_with_symbol
    controller = ControllerWithSymbolAsFilter
    assert_nothing_raised { test_process(controller,'no_raise') }
    assert_raise(Before) { test_process(controller,'raises_before') }
    assert_raise(After) { test_process(controller,'raises_after') }
    assert_nothing_raised { test_process(controller,'no_raise') }
  end

  def test_with_class
    controller = ControllerWithFilterClass
    assert_nothing_raised { test_process(controller,'no_raise') }
    assert_raise(After) { test_process(controller,'raises_after') }
  end

  def test_with_instance
    controller = ControllerWithFilterInstance
    assert_nothing_raised { test_process(controller,'no_raise') }
    assert_raise(After) { test_process(controller,'raises_after') }
  end

  def test_with_method
    controller = ControllerWithFilterMethod
    assert_nothing_raised { test_process(controller,'no_raise') }
    assert_raise(After) { test_process(controller,'raises_after') }
  end

  def test_with_proc
    controller = test_process(ControllerWithProcFilter,'no_raise')
    assert controller.template.assigns['before']
    assert controller.template.assigns['after']
  end

  def test_nested_filters
    controller = ControllerWithNestedFilters
    assert_nothing_raised do
      begin
        test_process(controller,'raises_both')
      rescue Before, After
      end
    end
    assert_raise Before do
      begin
        test_process(controller,'raises_both')
      rescue After
      end
    end
  end

  def test_filter_order_with_all_filter_types
    controller = test_process(ControllerWithAllTypesOfFilters,'no_raise')
    assert_equal 'before around (before yield) around_again (before yield) around_again (after yield) around (after yield) after',controller.template.assigns['ran_filter'].join(' ')
  end

  def test_filter_order_with_skip_filter_method
    controller = test_process(ControllerWithTwoLessFilters,'no_raise')
    assert_equal 'before around (before yield) around (after yield)',controller.template.assigns['ran_filter'].join(' ')
  end

  def test_first_filter_in_multiple_before_filter_chain_halts
    controller = ::FilterTest::TestMultipleFiltersController.new
    response = test_process(controller, 'fail_1')
    assert_equal '', response.body
    assert_equal 1, controller.instance_variable_get(:@try)
    assert controller.instance_variable_get(:@before_filter_chain_aborted)
  end

  def test_second_filter_in_multiple_before_filter_chain_halts
    controller = ::FilterTest::TestMultipleFiltersController.new
    response = test_process(controller, 'fail_2')
    assert_equal '', response.body
    assert_equal 2, controller.instance_variable_get(:@try)
    assert controller.instance_variable_get(:@before_filter_chain_aborted)
  end

  def test_last_filter_in_multiple_before_filter_chain_halts
    controller = ::FilterTest::TestMultipleFiltersController.new
    response = test_process(controller, 'fail_3')
    assert_equal '', response.body
    assert_equal 3, controller.instance_variable_get(:@try)
    assert controller.instance_variable_get(:@before_filter_chain_aborted)
  end

  protected
    def test_process(controller, action = "show")
      request = ActionController::TestRequest.new
      request.action = action
      controller.process(request, ActionController::TestResponse.new)
    end
end
