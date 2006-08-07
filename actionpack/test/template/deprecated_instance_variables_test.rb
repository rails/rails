require File.dirname(__FILE__) + '/../abstract_unit'

class DeprecatedInstanceVariablesTest < Test::Unit::TestCase
  class Target < ActionController::Base
    ActionController::Base::DEPRECATED_INSTANCE_VARIABLES.each do |var|
      class_eval <<-end_eval
        def old_#{var}; render :inline => '<%= @#{var}.inspect %>'  end
        def new_#{var}; render :inline => '<%= #{var}.inspect %>'   end
      end_eval
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
    end_eval
  end
end
