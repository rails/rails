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

  def test_registered_template_handler
    assert_same ActionView::Template.handler_for_extension(:erb), ActionView::Template.registered_template_handler("erb")
  end

  def test_registered_template_handler_does_not_fall_back_to_the_default
    assert_nil ActionView::Template.registered_template_handler(:unknown)
    assert_nil ActionView::Template.registered_template_handler(nil)
    assert_equal false, ActionView::Template.registered_template_handler(false)
  end

  def test_template_handler_extensions
    extensions = ActionView::Template.template_handler_extensions
    assert_equal %w(builder erb html raw ruby), extensions

    extensions << "custom"
    assert_equal %w(builder erb html raw ruby), ActionView::Template.template_handler_extensions
  end

  def test_register_default_template_handler
    ActiveSupport::Ractors.with(unshareable_proc_action: :raise) do
      default = ActionView::Template.register_default_template_handler :custom, lambda { |_, source| source }

      assert_same default, ActionView::Template.handler_for_extension(:unknown)
      assert_same default, ActionView::Template.registered_template_handler(:custom)
      assert_ractor_shareable ActionView::Template::Handlers.template_handlers
      assert_ractor_shareable default
    end
  end

  def test_register_default_template_handler_converts_the_extension_once
    extension = Object.new
    def extension.to_sym = (@calls = (@calls || 0) + 1) == 1 ? :custom : :other
    handler = ActionView::Template::Handlers::Raw.new.freeze

    ActionView::Template.register_default_template_handler extension, handler

    assert_same handler, ActionView::Template.registered_template_handler(:custom)
    assert_same handler, ActionView::Template.handler_for_extension(:unknown)
  end

  def test_compiling_with_erubi_does_not_load_herb
    script = <<~RUBY
      require "action_view"
      handler = ActionView::Template::Handlers::ERB.new
      [:html, :text].each do |format|
        template = ActionView::Template.new("<%= 1 %>", "test", handler, virtual_path: "test", format: format, locals: [])
        handler.call(template, template.source)
      end
      print ActionView::Template::Handlers::ERB.autoload?(:Herb).inspect
    RUBY

    output = IO.popen([RbConfig.ruby, "-I", File.expand_path("../../lib", __dir__), "-rbundler/setup", "-e", script], &:read)

    assert_equal %("action_view/template/handlers/erb/herb"), output
  end
end
