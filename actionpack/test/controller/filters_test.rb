require 'abstract_unit'
require 'active_support/core_ext/symbol'

class ActionController::Base
  class << self
    %w(append_around_filter prepend_after_filter prepend_around_filter prepend_before_filter skip_after_filter skip_before_filter skip_filter).each do |pending|
      define_method(pending) do |*args|
        $stderr.puts "#{pending} unimplemented: #{args.inspect}"
      end unless method_defined?(pending)
    end

    def before_filters
      filters = _process_action_callbacks.select { |c| c.kind == :before }
      filters.map! { |c| c.instance_variable_get(:@raw_filter) }
    end
  end

  def assigns(key = nil)
    assigns = {}
    instance_variable_names.each do |ivar|
      next if ActionController::Base.protected_instance_variables.include?(ivar)
      assigns[ivar[1..-1]] = instance_variable_get(ivar)
    end

    key.nil? ? assigns : assigns[key.to_s]
  end
end

class FilterTest < ActionController::TestCase

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
        if action_name == "fail_#{i}"
          head(404)
        end
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
    before_filter(:only => :show) {|c| c.instance_variable_set(:"@ran_proc_filter", true) }
  end

  class ExceptConditionProcController < ConditionalFilterController
    before_filter(:except => :show_without_filter) {|c| c.instance_variable_set(:"@ran_proc_filter", true) }
  end

  class ConditionalClassFilter
    def self.filter(controller) controller.instance_variable_set(:"@ran_class_filter", true) end
  end

  class OnlyConditionClassController < ConditionalFilterController
    before_filter ConditionalClassFilter, :only => :show
  end

  class ExceptConditionClassController < ConditionalFilterController
    before_filter ConditionalClassFilter, :except => :show_without_filter
  end

  class AnomolousYetValidConditionController < ConditionalFilterController
    before_filter(ConditionalClassFilter, :ensure_login, Proc.new {|c| c.instance_variable_set(:"@ran_proc_filter1", true)}, :except => :show_without_filter) { |c| c.instance_variable_set(:"@ran_proc_filter2", true)}
  end

  class ConditionalOptionsFilter < ConditionalFilterController
    before_filter :ensure_login, :if => Proc.new { |c| true }
    before_filter :clean_up_tmp, :if => Proc.new { |c| false }
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

  class SkippingAndLimitedController < TestController
    skip_before_filter :ensure_login
    before_filter :ensure_login, :only => :index

    def index
      render :text => 'ok'
    end

    def public
      render :text => 'ok'
    end
  end

  class SkippingAndReorderingController < TestController
    skip_before_filter :ensure_login
    before_filter :find_record
    before_filter :ensure_login

    def index
      render :text => 'ok'
    end

    private
      def find_record
        @ran_filter ||= []
        @ran_filter << "find_record"
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
    before_filter :conditional_in_parent_before, :only => [:show, :another_action]
    after_filter  :conditional_in_parent_after, :only => [:show, :another_action]

    private

      def conditional_in_parent_before
        @ran_filter ||= []
        @ran_filter << 'conditional_in_parent_before'
      end

      def conditional_in_parent_after
        @ran_filter ||= []
        @ran_filter << 'conditional_in_parent_after'
      end
  end

  class ChildOfConditionalParentController < ConditionalParentOfConditionalSkippingController
    skip_before_filter :conditional_in_parent_before, :only => :another_action
    skip_after_filter  :conditional_in_parent_after, :only => :another_action
  end

  class AnotherChildOfConditionalParentController < ConditionalParentOfConditionalSkippingController
    skip_before_filter :conditional_in_parent_before, :only => :show
  end

  class ProcController < PrependingController
    before_filter(proc { |c| c.instance_variable_set(:"@ran_proc_filter", true) })
  end

  class ImplicitProcController < PrependingController
    before_filter { |c| c.instance_variable_set(:"@ran_proc_filter", true) }
  end

  class AuditFilter
    def self.filter(controller)
      controller.instance_variable_set(:"@was_audited", true)
    end
  end

  class AroundFilter
    def before(controller)
      @execution_log = "before"
      controller.class.execution_log << " before aroundfilter " if controller.respond_to? :execution_log
      controller.instance_variable_set(:"@before_ran", true)
    end

    def after(controller)
      controller.instance_variable_set(:"@execution_log", @execution_log + " and after")
      controller.instance_variable_set(:"@after_ran", true)
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
      render :text => "hello"
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
      render :text => 'foo'
    end

    def bar
      render :text => 'bar'
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

  class ErrorToRescue < Exception; end

  class RescuingAroundFilterWithBlock
    def filter(controller)
      begin
        yield
      rescue ErrorToRescue => ex
        controller.__send__ :render, :text => "I rescued this: #{ex.inspect}"
      end
    end
  end

  class RescuedController < ActionController::Base
    around_filter RescuingAroundFilterWithBlock.new

    def show
      raise ErrorToRescue.new("Something made the bad noise.")
    end

  private
    def rescue_action(exception)
      raise exception
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
    test_process(PrependingController)
    assert_equal %w( wonderful_life ensure_login ), assigns["ran_filter"]
  end

  def test_running_filters_with_proc
    test_process(ProcController)
    assert assigns["ran_proc_filter"]
  end

  def test_running_filters_with_implicit_proc
    test_process(ImplicitProcController)
    assert assigns["ran_proc_filter"]
  end

  def test_running_filters_with_class
    test_process(AuditController)
    assert assigns["was_audited"]
  end

  def test_running_anomolous_yet_valid_condition_filters
    test_process(AnomolousYetValidConditionController)
    assert_equal %w( ensure_login ), assigns["ran_filter"]
    assert assigns["ran_class_filter"]
    assert assigns["ran_proc_filter1"]
    assert assigns["ran_proc_filter2"]

    test_process(AnomolousYetValidConditionController, "show_without_filter")
    assert_equal nil, assigns["ran_filter"]
    assert !assigns["ran_class_filter"]
    assert !assigns["ran_proc_filter1"]
    assert !assigns["ran_proc_filter2"]
  end

  def test_running_conditional_options
    test_process(ConditionalOptionsFilter)
    assert_equal %w( ensure_login ), assigns["ran_filter"]
  end

  def test_running_collection_condition_filters
    test_process(ConditionalCollectionFilterController)
    assert_equal %w( ensure_login ), assigns["ran_filter"]
    test_process(ConditionalCollectionFilterController, "show_without_filter")
    assert_equal nil, assigns["ran_filter"]
    test_process(ConditionalCollectionFilterController, "another_action")
    assert_equal nil, assigns["ran_filter"]
  end

  def test_running_only_condition_filters
    test_process(OnlyConditionSymController)
    assert_equal %w( ensure_login ), assigns["ran_filter"]
    test_process(OnlyConditionSymController, "show_without_filter")
    assert_equal nil, assigns["ran_filter"]

    test_process(OnlyConditionProcController)
    assert assigns["ran_proc_filter"]
    test_process(OnlyConditionProcController, "show_without_filter")
    assert !assigns["ran_proc_filter"]

    test_process(OnlyConditionClassController)
    assert assigns["ran_class_filter"]
    test_process(OnlyConditionClassController, "show_without_filter")
    assert !assigns["ran_class_filter"]
  end

  def test_running_except_condition_filters
    test_process(ExceptConditionSymController)
    assert_equal %w( ensure_login ), assigns["ran_filter"]
    test_process(ExceptConditionSymController, "show_without_filter")
    assert_equal nil, assigns["ran_filter"]

    test_process(ExceptConditionProcController)
    assert assigns["ran_proc_filter"]
    test_process(ExceptConditionProcController, "show_without_filter")
    assert !assigns["ran_proc_filter"]

    test_process(ExceptConditionClassController)
    assert assigns["ran_class_filter"]
    test_process(ExceptConditionClassController, "show_without_filter")
    assert !assigns["ran_class_filter"]
  end

  def test_running_before_and_after_condition_filters
    test_process(BeforeAndAfterConditionController)
    assert_equal %w( ensure_login clean_up_tmp), assigns["ran_filter"]
    test_process(BeforeAndAfterConditionController, "show_without_filter")
    assert_equal nil, assigns["ran_filter"]
  end

  def test_around_filter
    test_process(AroundFilterController)
    assert assigns["before_ran"]
    assert assigns["after_ran"]
  end

  def test_before_after_class_filter
    test_process(BeforeAfterClassFilterController)
    assert assigns["before_ran"]
    assert assigns["after_ran"]
  end

  def test_having_properties_in_around_filter
    test_process(AroundFilterController)
    assert_equal "before and after", assigns["execution_log"]
  end

  def test_prepending_and_appending_around_filter
    controller = test_process(MixedFilterController)
    assert_equal " before aroundfilter  before procfilter  before appended aroundfilter " +
                 " after appended aroundfilter  after procfilter  after aroundfilter ",
                 MixedFilterController.execution_log
  end

  def test_rendering_breaks_filtering_chain
    response = test_process(RenderingController)
    assert_equal "something else", response.body
    assert !assigns["ran_action"]
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
      response = DynamicDispatchController.action(action).call(request.env).last
      assert_equal action, response.body
    end
  end

  def test_running_prepended_before_and_after_filter
    test_process(PrependingBeforeAndAfterController)
    assert_equal %w( before_all between_before_all_and_after_all after_all ), assigns["ran_filter"]
  end

  def test_skipping_and_limiting_controller
    test_process(SkippingAndLimitedController, "index")
    assert_equal %w( ensure_login ), assigns["ran_filter"]
    test_process(SkippingAndLimitedController, "public")
    assert_nil assigns["ran_filter"]
  end

  def test_skipping_and_reordering_controller
    test_process(SkippingAndReorderingController, "index")
    assert_equal %w( find_record ensure_login ), assigns["ran_filter"]
  end

  def test_conditional_skipping_of_filters
    test_process(ConditionalSkippingController, "login")
    assert_nil assigns["ran_filter"]
    test_process(ConditionalSkippingController, "change_password")
    assert_equal %w( ensure_login find_user ), assigns["ran_filter"]

    test_process(ConditionalSkippingController, "login")
    assert_nil @controller.template.controller.instance_variable_get("@ran_after_filter")
    test_process(ConditionalSkippingController, "change_password")
    assert_equal %w( clean_up ), @controller.template.controller.instance_variable_get("@ran_after_filter")
  end

  def test_conditional_skipping_of_filters_when_parent_filter_is_also_conditional
    test_process(ChildOfConditionalParentController)
    assert_equal %w( conditional_in_parent_before conditional_in_parent_after ), assigns['ran_filter']
    test_process(ChildOfConditionalParentController, 'another_action')
    assert_nil assigns['ran_filter']
  end

  def test_condition_skipping_of_filters_when_siblings_also_have_conditions
    test_process(ChildOfConditionalParentController)
    assert_equal %w( conditional_in_parent_before conditional_in_parent_after ), assigns['ran_filter']
    test_process(AnotherChildOfConditionalParentController)
    assert_equal %w( conditional_in_parent_after ), assigns['ran_filter']
    test_process(ChildOfConditionalParentController)
    assert_equal %w( conditional_in_parent_before conditional_in_parent_after ), assigns['ran_filter']
  end

  def test_changing_the_requirements
    test_process(ChangingTheRequirementsController, "go_wild")
    assert_equal nil, assigns['ran_filter']
  end

  def test_a_rescuing_around_filter
    response = nil
    assert_nothing_raised do
      response = test_process(RescuedController)
    end

    assert response.success?
    assert_equal("I rescued this: #<FilterTest::ErrorToRescue: Something made the bad noise.>", response.body)
  end

  private
    def test_process(controller, action = "show")
      @controller = controller.is_a?(Class) ? controller.new : controller
      @request    = ActionController::TestRequest.new
      @response   = ActionController::TestResponse.new

      process(action)
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
    c.instance_variable_set(:"@before", true)
    b.call
    c.instance_variable_set(:"@after", true)
  end
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
  $vbf = true
  skip_filter :around_again
  $vbf = false
  skip_filter :after
end

class YieldingAroundFiltersTest < ActionController::TestCase
  include PostsController::AroundExceptions

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

  def test_with_proc
    test_process(ControllerWithProcFilter,'no_raise')
    assert assigns['before']
    assert assigns['after']
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
    test_process(ControllerWithAllTypesOfFilters,'no_raise')
    assert_equal 'before around (before yield) around_again (before yield) around_again (after yield) after around (after yield)', assigns['ran_filter'].join(' ')
  end

  def test_filter_order_with_skip_filter_method
    test_process(ControllerWithTwoLessFilters,'no_raise')
    assert_equal 'before around (before yield) around (after yield)', assigns['ran_filter'].join(' ')
  end

  def test_first_filter_in_multiple_before_filter_chain_halts
    controller = ::FilterTest::TestMultipleFiltersController.new
    response = test_process(controller, 'fail_1')
    assert_equal ' ', response.body
    assert_equal 1, controller.instance_variable_get(:@try)
  end

  def test_second_filter_in_multiple_before_filter_chain_halts
    controller = ::FilterTest::TestMultipleFiltersController.new
    response = test_process(controller, 'fail_2')
    assert_equal ' ', response.body
    assert_equal 2, controller.instance_variable_get(:@try)
  end

  def test_last_filter_in_multiple_before_filter_chain_halts
    controller = ::FilterTest::TestMultipleFiltersController.new
    response = test_process(controller, 'fail_3')
    assert_equal ' ', response.body
    assert_equal 3, controller.instance_variable_get(:@try)
  end

  protected
    def test_process(controller, action = "show")
      @controller = controller.is_a?(Class) ? controller.new : controller
      process(action)
    end
end
