require File.dirname(__FILE__) + '/../abstract_unit'

class FilterTest < Test::Unit::TestCase
  class TestController < ActionController::Base
    before_filter :ensure_login

    def show
      render_text "ran action"
    end

    private
      def ensure_login
        @ran_filter ||= []
        @ran_filter << "ensure_login"
      end
  end
  
  class LimitedFilterController < ActionController::Base
    before_filter :ensure_login, :for => :show

    def show
      render_text "ran action"
    end

    def show_without_filter
      render_text "ran action without filter"
    end

    private
      def ensure_login
        @ran_filter ||= []
        @ran_filter << "ensure_login"
      end
  end
  
  class PrependingController < TestController
    prepend_before_filter :wonderful_life

    private
      def wonderful_life
        @ran_filter ||= []
        @ran_filter << "wonderful_life"
      end
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

  class BadFilterController < ActionController::Base
    before_filter 2
    
    def show() "show" end
    
    protected
      def rescue_action(e) raise(e) end
  end

  class AroundFilterController < PrependingController
    around_filter AroundFilter.new
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
  

  def test_added_filter_to_inheritance_graph
    assert_equal [ :fire_flash, :ensure_login ], TestController.before_filters
  end

  def test_base_class_in_isolation
    assert_equal [ :fire_flash ], ActionController::Base.before_filters
  end
  
  def test_prepending_filter
    assert_equal [ :wonderful_life, :fire_flash, :ensure_login ], PrependingController.before_filters
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

  def test_running_limited_filters
    assert_equal %w( fire_flash ensure_login ), test_process(LimitedFilterController, "show").template.assigns["ran_filter"]
    assert_equal %w( fire_flash ), test_process(LimitedFilterController, "show_without_filter").template.assigns["ran_filter"]
  end
  
  def test_bad_filter
    assert_raises(ActionController::ActionControllerError) { 
      test_process(BadFilterController)
    }
  end
  
  def test_around_filter
    controller = test_process(AroundFilterController)
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

  private
    def test_process(controller, action = "show")
      request = ActionController::TestRequest.new
      request.action = action
      controller.process(request, ActionController::TestResponse.new)
    end
end