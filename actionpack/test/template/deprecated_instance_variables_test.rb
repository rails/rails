require File.dirname(__FILE__) + '/../abstract_unit'

class DeprecatedViewInstanceVariablesTest < Test::Unit::TestCase
  class DeprecatedInstanceVariablesController < ActionController::Base
    self.template_root = "#{File.dirname(__FILE__)}/../fixtures/"

    def self.controller_path; 'deprecated_instance_variables' end

    ActionController::Base::DEPRECATED_INSTANCE_VARIABLES.each do |var|
      class_eval <<-end_eval
        def old_#{var}_inline;  render :inline => '<%= @#{var}.to_s %>'  end
        def new_#{var}_inline;  render :inline => '<%= #{var}.to_s %>'   end
        def old_#{var}_partial; render :partial => '#{var}_ivar'    end
        def new_#{var}_partial; render :partial => '#{var}_method'  end
      end_eval
    end

    def rescue_action(e) raise e end
  end

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = DeprecatedInstanceVariablesController.new
  end

  ActionController::Base::DEPRECATED_INSTANCE_VARIABLES.each do |var|
    class_eval <<-end_eval, __FILE__, __LINE__
      def test_old_#{var}_is_deprecated
        assert_deprecated('@#{var}') { get :old_#{var}_inline }
      end
      def test_new_#{var}_isnt_deprecated
        assert_not_deprecated { get :new_#{var}_inline }
      end
      def test_old_#{var}_partial_is_deprecated
        assert_deprecated('@#{var}') { get :old_#{var}_partial }
      end
      def test_new_#{var}_partial_isnt_deprecated
        assert_not_deprecated { get :new_#{var}_partial }
      end
    end_eval
  end
end
