# frozen_string_literal: true

require "test_helper"

class ActionText::ControllerRenderTest < ActionDispatch::IntegrationTest
  test "uses current request environment" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpg")
    message = Message.create!(content: ActionText::Content.new.append_attachables(blob))

    host! "loocalhoost"
    get message_path(message)
    assert_dom "#content img" do |imgs|
      imgs.each { |img| assert_match %r"//loocalhoost/", img["src"] }
    end
  end

  test "renders as HTML when the request format is not HTML" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpg")
    message = Message.create!(content: ActionText::Content.new.append_attachables(blob))

    host! "loocalhoost"
    get message_path(message, format: :json)
    content = Nokogiri::HTML::DocumentFragment.parse(response.parsed_body["content"])
    assert_dom content, "img:match('src', ?)", %r"//loocalhoost/.+/racecar"
  end

  test "resolves partials when controller is namespaced" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpg")
    message = Message.create!(content: ActionText::Content.new.append_attachables(blob))

    get admin_message_path(message)
    assert_dom "#content-html .trix-content .attachment--jpg"
  end

  test "resolves ActionText::Attachable based on their to_attachable_partial_path" do
    alice = people(:alice)

    get messages_path

    assert_dom ".mentioned-person", text: alice.name
  end
end
