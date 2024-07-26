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

  class AuditFilter
    def self.filter(controller)
      controller.assigns["was_audited"] = true
    end
  end
  
  class AuditController < ActionController::Base
    before_filter(AuditFilter)
  end

  class BadFilterController < ActionController::Base
    before_filter 2
    
    def show() "show" end
    
    protected
      def rescue_action(e) raise e end
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
  
  def test_running_filters_with_class
    assert test_process(AuditController).template.assigns["was_audited"]
  end
  
  def test_bad_filter
    assert_raises(ActionController::ActionControllerError) { 
      test_process(BadFilterController)
    }
  end
  
  private
    def test_process(controller)
      request = ActionController::TestRequest.new
      request.action = "show"
      controller.process(request, ActionController::TestResponse.new)
    end
end