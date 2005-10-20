require File.dirname(__FILE__) + '/../abstract_unit'
require 'test/unit'
require 'pp' # require 'pp' early to prevent hidden_methods from not picking up the pretty-print methods until too late

# This file currently contains a few controller UTs
# I couldn't find where the current base tests are, so I created this file.
# If there aren't any base-specific UTs, then this file should grow as they
# are written. If there are, or there is a better place for these, then I will
# move them to the correct location.
#
# Nicholas Seckar aka. Ulysses

# Provide a static version of the Controllers module instead of the auto-loading version.
# We don't want these tests to fail when dependencies are to blame.
module Controllers
  module Submodule
    class ContainedEmptyController < ActionController::Base
    end
    class ContainedNonEmptyController < ActionController::Base
      def public_action
      end
      
      hide_action :hidden_action
      def hidden_action
      end
      
      def another_hidden_action
      end
      hide_action :another_hidden_action
    end
    class SubclassedController < ContainedNonEmptyController
      hide_action :public_action # Hiding it here should not affect the superclass.
    end
  end
  class EmptyController < ActionController::Base
    include ActionController::Caching
  end
  class NonEmptyController < ActionController::Base
    def public_action
    end
    
    hide_action :hidden_action
    def hidden_action
    end
  end
end

class ControllerClassTests < Test::Unit::TestCase
  def test_controller_path
    assert_equal 'empty', Controllers::EmptyController.controller_path
    assert_equal 'submodule/contained_empty', Controllers::Submodule::ContainedEmptyController.controller_path
  end
  def test_controller_name
    assert_equal 'empty', Controllers::EmptyController.controller_name
    assert_equal 'contained_empty', Controllers::Submodule::ContainedEmptyController.controller_name
 end
end

class ControllerInstanceTests < Test::Unit::TestCase
  def setup
    @empty = Controllers::EmptyController.new
    @contained = Controllers::Submodule::ContainedEmptyController.new
    @empty_controllers = [@empty, @contained, Controllers::Submodule::SubclassedController.new]
    
    @non_empty_controllers = [Controllers::NonEmptyController.new,
                              Controllers::Submodule::ContainedNonEmptyController.new]
  end

  def test_action_methods
    @empty_controllers.each do |c|
      assert_equal Set.new, c.send(:action_methods), "#{c.class.controller_path} should be empty!"
    end
    @non_empty_controllers.each do |c|
      assert_equal Set.new('public_action'), c.send(:action_methods), "#{c.class.controller_path} should not be empty!"
    end
  end
end
