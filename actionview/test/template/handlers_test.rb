# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/ractors_assertions"
require "active_support/core_ext/object/with"

class TemplateHandlersTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  include ActiveSupport::Testing::RactorsAssertions

  def test_built_in_handler_registry_is_ractor_shareable
    assert_ractor_shareable ActionView::Template::Handlers.template_handlers
    assert_ractor_shareable ActionView::Template::Handlers.extensions
  end

  if defined?(Ractor) && RUBY_VERSION >= "4.0"
    def test_handlers_can_be_looked_up_from_a_ractor
      handler_name = Ractor.new do
        ActionView::Template.handler_for_extension(:erb).class.name
      end.value

      assert_equal "ActionView::Template::Handlers::ERB", handler_name
    end
  end

  def test_registering_a_proc_handler_keeps_the_registry_shareable
    ActiveSupport::Ractors.with(unshareable_proc_action: :raise) do
      ActionView::Template.register_template_handler :custom, lambda { |_, source| source }

      assert_ractor_shareable ActionView::Template::Handlers.template_handlers
    end
  ensure
    ActionView::Template.unregister_template_handler :custom
  end
end
