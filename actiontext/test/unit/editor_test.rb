# frozen_string_literal: true

require "test_helper"

class ActionText::EditorTest < ActionView::TestCase
  test "#as_canonical returns Fragment for storage" do
    expected = "<div>hello, world</div>"
    fragment = Fragment.wrap(expected)
    editor = Editor.new

    actual = editor.as_canonical(fragment)

    assert_kind_of Fragment, actual
    assert_dom_equal expected, actual.to_html
  end

  test "#as_editable returns Fragment for editing" do
    expected = "<div>hello, world</div>"
    fragment = Fragment.wrap(expected)
    editor = Editor.new

    actual = editor.as_editable(fragment)

    assert_kind_of Fragment, actual
    assert_dom_equal expected, actual.to_html
  end
end

class ActionText::Editor::SubclassTest < ActionView::TestCase
  class TestEditor < ActionText::Editor
    def as_canonical(editable_fragment)
      editable_fragment = editable_fragment.replace "test-editor-attachment" do |editor_attachment|
        ActionText::Attachment.from_attributes(
          "sgid" => editor_attachment["sgid"],
          "content-type" => editor_attachment["content-type"]
        )
      end

      super
    end

    def as_editable(canonical_fragment)
      canonical_fragment = canonical_fragment.replace ActionText::Attachment.tag_name do |action_text_attachment|
        attachment_attributes = {
          "sgid" => action_text_attachment["sgid"],
          "content-type" => action_text_attachment["content-type"]
        }

        ActionText::HtmlConversion.create_element("test-editor-attachment", attachment_attributes)
      end

      super
    end
  end

  test "#as_canonical transforms Fragment for storage" do
    fragment = Fragment.wrap(<<~HTML)
      <test-editor-attachment sgid="abc123" content-type="plain/text"></test-editor-attachment>
    HTML
    editor = TestEditor.new

    actual = editor.as_canonical(fragment)

    assert_kind_of Fragment, actual
    assert_dom_equal <<~HTML, actual.to_html
      <action-text-attachment sgid="abc123" content-type="plain/text"></action-text-attachment>
    HTML
  end

  test "#as_editable transforms Fragment for editing" do
    fragment = Fragment.wrap(<<~HTML)
      <action-text-attachment sgid="abc123" content-type="plain/text"></action-text-attachment>
    HTML
    editor = TestEditor.new

    actual = editor.as_editable(fragment)

    assert_kind_of Fragment, actual
    assert_dom_equal <<~HTML, actual.to_html
      <test-editor-attachment sgid="abc123" content-type="plain/text"></test-editor-attachment>
    HTML
  end

  test "#editor_name removes the Editor suffix" do
    editor = TestEditor.new

    assert_equal "test", editor.editor_name
  end

  test "#editor_tag returns a renderable" do
    editor = TestEditor.new
    editor_tag = editor.editor_tag(id: "test_editor_id", name: "message[body]", value: "<div>hello</div>")

    render(editor_tag)

    element = rendered.html.at("test-editor")
    assert_equal "message[body]", element["name"]
    assert_equal "test_editor_id", element["id"]
    assert_equal "test-content", element["class"]
    assert_equal "<div>hello</div>", element["value"]
  end
end
