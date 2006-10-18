require File.dirname(__FILE__) + '/../abstract_unit'

class DeprecatedControllerInstanceVariablesTest < Test::Unit::TestCase
  class Target < ActionController::Base
    def initialize(run = nil)
      instance_eval(run) if run
      super()
    end

    def noop
      render :nothing => true
    end

    ActionController::Base::DEPRECATED_INSTANCE_VARIABLES.each do |var|
      class_eval "def old_#{var}; render :text => @#{var}.to_s end"
      class_eval "def new_#{var}; render :text => #{var}.to_s end"
      class_eval "def internal_#{var}; render :text => @_#{var}.to_s end"
    end

    def rescue_action(e) raise e end
  end

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = Target.new
  end

  ActionController::Base::DEPRECATED_INSTANCE_VARIABLES.each do |var|
    class_eval <<-end_eval, __FILE__, __LINE__
      def test_old_#{var}_is_deprecated
        assert_deprecated('@#{var}') { get :old_#{var} }
      end
      def test_new_#{var}_isnt_deprecated
        assert_not_deprecated { get :new_#{var} }
      end
      def test_internal_#{var}_isnt_deprecated
        assert_not_deprecated { get :internal_#{var} }
      end
      def test_#{var}_raises_if_already_set
        assert_raise(RuntimeError) do
          @controller = Target.new '@#{var} = Object.new'
          get :noop
        end
      end
    end_eval
  end
end
