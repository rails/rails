require 'abstract_unit'

class SessionManagementTest < Test::Unit::TestCase
  class SessionOffController < ActionController::Base
    session :off

    def show
      render :text => "done"
    end

    def tell
      render :text => "done"
    end
  end

  class SessionOffOnController < ActionController::Base
    session :off
    session :on, :only => :tell

    def show
      render :text => "done"
    end

    def tell
      render :text => "done"
    end
  end

  class TestController < ActionController::Base
    session :off, :only => :show
    session :session_secure => true, :except => :show
    session :off, :only => :conditional,
            :if => Proc.new { |r| r.parameters[:ws] }

    def show
      render :text => "done"
    end

    def tell
      render :text => "done"
    end

    def conditional
      render :text => ">>>#{params[:ws]}<<<"
    end
  end

  class SpecializedController < SessionOffController
    session :disabled => false, :only => :something

    def something
      render :text => "done"
    end

    def another
      render :text => "done"
    end
  end

  class AssociationCachingTestController < ActionController::Base
    class ObjectWithAssociationCache
      def initialize
        @cached_associations = false
      end

      def fetch_associations
        @cached_associations = true
      end

      def clear_association_cache
        @cached_associations = false
      end

      def has_cached_associations?
        @cached_associations
      end
    end

    def show
      session[:object] = ObjectWithAssociationCache.new
      session[:object].fetch_associations
      if session[:object].has_cached_associations?
        render :text => "has cached associations"
      else
        render :text => "does not have cached associations"
      end
    end

    def tell
      if session[:object]
        if session[:object].has_cached_associations?
          render :text => "has cached associations"
        else
          render :text => "does not have cached associations"
        end
      else
        render :text => "there is no object"
      end
    end
  end


  def setup
    @request, @response = ActionController::TestRequest.new,
      ActionController::TestResponse.new
  end

  def test_session_off_globally
    @controller = SessionOffController.new
    get :show
    assert_equal false, @request.session_options
    get :tell
    assert_equal false, @request.session_options
  end

  def test_session_off_then_on_globally
    @controller = SessionOffOnController.new
    get :show
    assert_equal false, @request.session_options
    get :tell
    assert_instance_of Hash, @request.session_options
    assert_equal false, @request.session_options[:disabled]
  end
  
  def test_session_off_conditionally
    @controller = TestController.new
    get :show
    assert_equal false, @request.session_options
    get :tell
    assert_instance_of Hash, @request.session_options
    assert @request.session_options[:session_secure]
  end

  def test_controller_specialization_overrides_settings
    @controller = SpecializedController.new
    get :something
    assert_instance_of Hash, @request.session_options
    get :another
    assert_equal false, @request.session_options
  end

  def test_session_off_with_if
    @controller = TestController.new
    get :conditional
    assert_instance_of Hash, @request.session_options
    get :conditional, :ws => "ws"
    assert_equal false, @request.session_options
  end
  
  def test_session_store_setting
    ActionController::Base.session_store = :drb_store
    assert_equal CGI::Session::DRbStore, ActionController::Base.session_store

    if Object.const_defined?(:ActiveRecord)
      ActionController::Base.session_store = :active_record_store
      assert_equal CGI::Session::ActiveRecordStore, ActionController::Base.session_store
    end
  end
  
  def test_process_cleanup_with_session_management_support
    @controller = AssociationCachingTestController.new
    get :show
    assert_equal "has cached associations", @response.body
    get :tell
    assert_equal "does not have cached associations", @response.body
  end
  
  def test_session_is_enabled
    @controller = TestController.new
    get :show
    assert_nothing_raised do
      assert_equal false, @controller.session_enabled?
    end
    
    get :tell
    assert @controller.session_enabled?
  end
end
