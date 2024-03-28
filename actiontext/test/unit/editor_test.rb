# frozen_string_literal: true

require "test_helper"

class ActionText::EditorTest < ActiveSupport::TestCase
  test "constructor assigns name from constructor" do
    editor = ActionText::Editor.new :trix

    assert_equal :trix, editor.name
  end

  test "constructor merges constructor options into config" do
    editor = ActionText::Editor.new :trix, attachments: {
      prefix: "trix",
      tag_name: "figure"
    }

    assert_equal "trix", editor.config.attachments[:prefix]
    assert_equal "figure", editor.config.attachments[:tag_name]
  end
end
