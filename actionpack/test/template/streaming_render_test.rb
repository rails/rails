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
    @controller_view = TestController.new.view_context
  end

  def buffered_render(options)
    body = @view.render_body(options)
    string = ""
    body.each do |piece|
      string << piece
    end
    string
  end

  def test_render_template_without_layout
    assert_equal "Hello world!", buffered_render(:template => "test/hello_world")
  end

  def test_render_template_with_layout
    assert_equal %(<title></title>\nHello world!\n),
      buffered_render(:template => "test/hello_world.erb", :layout => "layouts/yield")
  end
end if defined?(Fiber)