# frozen_string_literal: true

require "test_helper"

class ActionText::RichTextTest < ActiveSupport::TestCase
  test "sets default editor_name" do
    ActionText::RichText.with editor: :trix do
      model = ActionText::RichText.new

      assert_equal :trix, model.editor_name
    end
  end

  test "does not override existing editor_name with default" do
    ActionText::RichText.with editor: :trix do
      model = ActionText::RichText.new editor_name: :ckeditor

      assert_equal :ckeditor, model.editor_name
    end
  end

  test "validates editor_name presence" do
    model = ActionText::RichText.new
    model.editor_name = nil

    valid = model.validate

    assert_not valid
    assert_includes model.errors, :editor_name
  end
end
