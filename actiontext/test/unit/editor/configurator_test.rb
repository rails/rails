# frozen_string_literal: true

require "test_helper"

class ActionText::Editor::ConfiguratorTest < ActiveSupport::TestCase
  test "builds correct editor instance based on editor name" do
    configurator = ActionText::Editor::Configurator.new(trix: {})
    editor = configurator.build(:trix)
    assert_instance_of ActionText::Editor::TrixEditor, editor
  end

  test "raises error when passing non-existent editor name" do
    configurator = ActionText::Editor::Configurator.new({})
    assert_raise RuntimeError do
      configurator.build(:bigfoot)
    end
  end

  test "inspect attributes" do
    config = {
      trix: {},
      lexxy: {}
    }

    configurator = ActionText::Editor::Configurator.new(config)
    assert_match(/#<ActionText::Editor::Configurator configurations=\[:trix, :lexxy\]>/, configurator.inspect)

    configurator = ActionText::Editor::Configurator.new({})
    assert_match(/#<ActionText::Editor::Configurator>/, configurator.inspect)
  end
end
