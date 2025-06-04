# frozen_string_literal: true

require "test_helper"

class ActionText::ContentHelperTest < ActionView::TestCase
  include ActionText::ContentHelper

  setup do
    self.prefix_partial_path_with_controller_namespace = false
  end

  test "renders content without attachments" do
    content = ActionText::Content.new("<p>Hello world</p>")
    rendered = render_action_text_content(content)
    assert_includes rendered, "Hello world"
  end

  test "renders content with blob attachment" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    content = ActionText::Content.new.append_attachables(blob)

    rendered = render_action_text_content(content)
    assert_includes rendered, "racecar.jpg"
    assert_includes rendered, "attachment"
  end

  test "renders content with attachment locals" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    content = ActionText::Content.new.append_attachables(blob)

    # Mock the render method to capture the locals being passed
    rendered_locals = []
    original_render = method(:render)
    define_singleton_method(:render) do |**options|
      if options[:partial]&.respond_to?(:to_partial_path)
        rendered_locals << options[:locals]
      end
      original_render.call(**options)
    end

    render_action_text_content(content, attachment_locals: { current_user: "test_user" })

    # Verify that our custom locals were passed through
    assert rendered_locals.any? { |locals| locals[:current_user] == "test_user" }
    assert rendered_locals.any? { |locals| locals.key?(:in_gallery) }
  end

  test "renders content with attachment galleries and locals" do
    blob1 = create_file_blob(filename: "image1.jpg", content_type: "image/jpeg")
    blob2 = create_file_blob(filename: "image2.jpg", content_type: "image/jpeg")

    gallery_html = %Q(
      <action-text-attachment-gallery>
        <action-text-attachment sgid="#{blob1.attachable_sgid}"></action-text-attachment>
        <action-text-attachment sgid="#{blob2.attachable_sgid}"></action-text-attachment>
      </action-text-attachment-gallery>
    )

    content = ActionText::Content.new(gallery_html)

    # Mock the render method to capture the locals being passed
    rendered_locals = []
    original_render = method(:render)
    define_singleton_method(:render) do |**options|
      if options[:partial]&.respond_to?(:to_partial_path)
        rendered_locals << options[:locals]
      end
      original_render.call(**options)
    end

    render_action_text_content(content, attachment_locals: { current_user: "gallery_user" })

    # Verify that gallery attachments receive both custom locals and in_gallery: true
    gallery_locals = rendered_locals.select { |locals| locals[:in_gallery] == true }
    assert gallery_locals.any? { |locals| locals[:current_user] == "gallery_user" }
  end

  test "backwards compatibility - renders without attachment_locals parameter" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    content = ActionText::Content.new.append_attachables(blob)

    # This should work without throwing an error
    rendered = render_action_text_content(content)
    assert_includes rendered, "racecar.jpg"
  end

  test "passes locals through content partial" do
    blob = create_file_blob(filename: "test.jpg", content_type: "image/jpeg")
    content = ActionText::Content.new.append_attachables(blob)

    # Test rendering through the partial with locals
    rendered = render(partial: "action_text/contents/content", locals: {
      content: content,
      current_user: "partial_user"
    })

    assert_includes rendered, "test.jpg"
  end

  private
    def create_file_blob(filename:, content_type:)
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("file content"),
        filename: filename,
        content_type: content_type
      )
    end
end
