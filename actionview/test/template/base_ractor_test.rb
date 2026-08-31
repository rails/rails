# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/ractors_assertions"

class BaseRactorTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::RactorsAssertions

  test "field_error_proc is readable from a non-main Ractor" do
    assert_equal ActionView::Base.field_error_proc,
      on_ractor { ActionView::Base.field_error_proc }
  end

  test "the default field_error_proc is shareable" do
    assert_ractor_shareable ActionView::Base.field_error_proc
  end

  if RUBY_VERSION >= "4.0"
    test "assigning field_error_proc makes it shareable when the application opts in" do
      old_proc = ActionView::Base.field_error_proc
      old_action = ActiveSupport::Ractors.unshareable_proc_action
      ActiveSupport::Ractors.unshareable_proc_action = :raise

      ActionView::Base.field_error_proc = proc { |html_tag, instance| html_tag }
      assert_ractor_shareable ActionView::Base.field_error_proc
    ensure
      ActiveSupport::Ractors.unshareable_proc_action = old_action
      ActionView::Base.field_error_proc = old_proc
    end

    test "assigning an unshareable field_error_proc raises when the application opts in" do
      old_proc = ActionView::Base.field_error_proc
      old_action = ActiveSupport::Ractors.unshareable_proc_action
      ActiveSupport::Ractors.unshareable_proc_action = :raise

      mutable = +"unshareable"
      assert_raises(Ractor::IsolationError) do
        ActionView::Base.field_error_proc = proc { mutable }
      end
      assert_same old_proc, ActionView::Base.field_error_proc
    ensure
      ActiveSupport::Ractors.unshareable_proc_action = old_action
      ActionView::Base.field_error_proc = old_proc
    end
  end
end
