# encoding: utf-8
require 'abstract_unit'
require 'controller/fake_models'

class TestController < ActionController::Base
end


class FiberedTest < ActiveSupport::TestCase

  def setup
    view_paths = ActionController::Base.view_paths
    @assigns = { :secret => 'in the sauce' }
    @view = ActionView::Base.new(view_paths, @assigns)
    @view.magic_medicine = true
    @controller_view = TestController.new.view_context
  end

  def test_render_template
    assert_equal "Hello world!", @view.render(:template => "test/hello_world")
  end

  def test_render_with_layout
    assert_equal %(<title></title>\nHello world!\n),
      @view.render(:template => "test/hello_world.erb", :layout => "layouts/yield")
  end
end if defined?(Fiber)