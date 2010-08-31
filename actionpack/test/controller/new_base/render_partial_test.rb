require 'abstract_unit'

module RenderPartial

  class BasicController < ActionController::Base

    self.view_paths = [ActionView::FixtureResolver.new(
      "render_partial/basic/_basic.html.erb"    => "BasicPartial!",
      "render_partial/basic/basic.html.erb"      => "<%= @test_unchanged = 'goodbye' %><%= render :partial => 'basic' %><%= @test_unchanged %>"
    )]

    def changing
      @test_unchanged = 'hello'
      render :action => "basic"
    end
  end

  class TestPartial < Rack::TestCase
    testing BasicController

    test "rendering a partial in ActionView doesn't pull the ivars again from the controller" do
      get :changing
      assert_response("goodbyeBasicPartial!goodbye")
    end
  end

end
