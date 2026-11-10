# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/ractors_assertions"

class BaseRactorTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::RactorsAssertions

  test "settings are readable from a non-main Ractor" do
    expected = [
      ActionView::Base.field_error_proc,
      ActionView::Base.streaming_completion_on_exception,
      ActionView::Base.automatically_disable_submit_tag,
      ActionView::Base.remove_hidden_field_autocomplete,
    ]

    assert_equal expected, on_ractor {
      [
        ActionView::Base.field_error_proc,
        ActionView::Base.streaming_completion_on_exception,
        ActionView::Base.automatically_disable_submit_tag,
        ActionView::Base.remove_hidden_field_autocomplete,
      ]
    }
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

  class DefaultFormBuilderRactorTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include ActiveSupport::Testing::RactorsAssertions

    test "default_form_builder is readable from a non-main Ractor" do
      assert_equal ActionView::Base.default_form_builder,
        on_ractor { ActionView::Base.default_form_builder }
    end
  end
end

class BaseDefaultFormatsRactorTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  include ActiveSupport::Testing::RactorsAssertions

  test "default_formats is readable from a non-main Ractor once the Mime registry is frozen" do
    Mime.eager_load!

    assert_equal ActionView::Base.default_formats,
      on_ractor { ActionView::Base.default_formats }
  end
end
