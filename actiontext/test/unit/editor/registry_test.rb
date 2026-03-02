# frozen_string_literal: true

require "test_helper"

class ActionText::Editor::RegistryTest < ActiveSupport::TestCase
  test "inspect attributes" do
    registry = ActionText::Editor::Registry.new({})
    assert_match(/#<ActionText::Editor::Registry>/, registry.inspect)
  end

  test "inspect attributes with config" do
    config = {
      trix: {},
      lexxy: {}
    }

    registry = ActionText::Editor::Registry.new(config)
    assert_match(/#<ActionText::Editor::Registry configurations=\[:trix, :lexxy\]>/, registry.inspect)
  end
end
