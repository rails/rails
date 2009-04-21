require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module HappyPath
  
  class RenderImplicitActionController < ActionController::Base2
    # No actions yet, they are implicit
  end
  
  class TestRendersActionImplicitly < SimpleRouteCase
  
    test "renders action implicitly" do
      assert true
    end
  
  end
end