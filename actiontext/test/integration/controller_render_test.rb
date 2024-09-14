# frozen_string_literal: true

require "test_helper"

class ActionText::ControllerRenderTest < ActionDispatch::IntegrationTest
  test "uses current request environment" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    message = Message.create!(content: ActionText::Content.new.append_attachables(blob))

    host! "loocalhoost"
    get message_path(message)
    assert_select "#content img" do |imgs|
      imgs.each { |img| assert_match %r"//loocalhoost/", img["src"] }
    end
  end

  test "renders as HTML when the request format is not HTML" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    message = Message.create!(content: ActionText::Content.new.append_attachables(blob))

    host! "loocalhoost"
    get message_path(message, format: :json)
    content = ActionText.html_document_fragment_class.parse(response.parsed_body["content"])
    assert_select content, "img:match('src', ?)", %r"//loocalhoost/.+/racecar"
  end

  test "renders Trix with content attachment as HTML when the request format is not HTML" do
    message_with_person_attachment = messages(:hello_alice)

    get edit_message_path(message_with_person_attachment, format: :json)

    form_html = response.parsed_body["form"]
    assert_match %r" class=\S+mentionable-person\b", form_html
  end

  test "resolves partials when controller is namespaced" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    message = Message.create!(content: ActionText::Content.new.append_attachables(blob))

    get admin_message_path(message)
    assert_select "#content-html .trix-content .attachment--jpg"
  end

  test "resolves ActionText::Attachable based on their to_attachable_partial_path" do
    alice = people(:alice)

    get messages_path

    assert_select ".mentioned-person", text: alice.name
  end

  test "resolves missing ActionText::Attachable based on their to_missing_attachable_partial_path" do
    alice = people(:alice)
    alice.destroy!

    get messages_path

    assert_select ".missing-attachable", text: "Missing person"
  end
end
