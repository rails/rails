# frozen_string_literal: true

require "test_helper"

module ActionText
  class Editor::TrixEditorTest < ActionView::TestCase
    test "#as_canonical transforms Fragment for storage" do
      expected = "<div>hello, world</div>"
      fragment = Fragment.wrap(expected)
      editor = ActionText::Editor::TrixEditor.new

      actual = editor.as_canonical(fragment)

      assert_kind_of Fragment, actual
      assert_dom_equal expected, actual.to_html
    end

    test "#as_editable transforms Fragment for editing" do
      expected = "<div>hello, world</div>"
      fragment = Fragment.wrap(expected)
      editor = ActionText::Editor::TrixEditor.new

      actual = editor.as_editable(fragment)

      assert_kind_of Fragment, actual
      assert_dom_equal expected, actual.to_html
    end

    test "#editor_name removes the Editor suffix" do
      editor = ActionText::Editor::TrixEditor.new

      assert_equal "trix", editor.editor_name
    end

    test "#editor_tag returns a renderable" do
      editor = ActionText::Editor::TrixEditor.new

      render(editor.editor_tag(name: "message[body]"))

      trix_editor = rendered.html.at("trix-editor")
      input       = rendered.html.at("input[id][type=hidden]")
      assert_not trix_editor.key?("name")
      assert_equal "trix-content", trix_editor["class"]
      assert_equal input["id"], trix_editor["input"]
      assert_equal "message[body]", input["name"]
    end

    test "#editor_tag forwards the :form to its input element" do
      editor = ActionText::Editor::TrixEditor.new

      render(editor.editor_tag(form: "form_id"))

      assert_dom "trix-editor[form]", count: 0
      assert_dom "input[form=?]", "form_id"
    end

    test "#editor_tag forwards the :value attribute to its input element" do
      editor = ActionText::Editor::TrixEditor.new

      render(editor.editor_tag(value: "<div>hello</div>"))

      assert_dom "trix-editor[value]", count: 0
      assert_dom "input[value=?]", "<div>hello</div>"
    end
  end
end
