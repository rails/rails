# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/ractors_assertions"
require "active_support/core_ext/object/with"

class LayoutsRactorTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::RactorsAssertions

  def controller_class_with_proc_layout(layout_proc)
    Class.new(AbstractController::Base) do
      include AbstractController::Rendering
      include ActionView::Rendering
      include ActionView::Layouts

      layout layout_proc
    end
  end

  test "an unshareable proc layout works without Ractors" do
    words = []
    klass = controller_class_with_proc_layout(proc { (words << "layout").join })

    assert_equal "layout", klass.new.send(:_layout_from_proc)
    assert_equal ["layout"], words
  end

  test "a proc layout is callable from a non-main Ractor when made shareable" do
    klass = ActiveSupport::Ractors.with(unshareable_proc_action: :raise) do
      controller_class_with_proc_layout(proc { "overwritten" })
    end

    assert_equal "overwritten", on_ractor(klass) { |k| k.new.send(:_layout_from_proc) }
  end

  test "a lambda layout keeps its arity and receives the controller when made shareable" do
    klass = ActiveSupport::Ractors.with(unshareable_proc_action: :raise) do
      controller_class_with_proc_layout(->(controller) { controller.is_a?(AbstractController::Base) ? "lambda" : "wrong" })
    end

    assert_equal "lambda", on_ractor(klass) { |k|
      controller = k.new
      controller.send(:_layout_from_proc, controller)
    }
  end
end
