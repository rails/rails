# frozen_string_literal: true

require "test_helper"

class ActionText::ControllerRenderTest < ActionDispatch::IntegrationTest
  test "uses current request environment" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpg")
    message = Message.create!(content: ActionText::Content.new.append_attachables(blob))

    host! "loocalhoost"
    get message_path(message)
    assert_select "#content img" do |imgs|
      imgs.each { |img| assert_match %r"//loocalhoost/", img["src"] }
    end
  end

  test "resolves partials when controller is namespaced" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpg")
    message = Message.create!(content: ActionText::Content.new.append_attachables(blob))

    get admin_message_path(message)
    assert_select "#content-html .trix-content .attachment--jpg"
  end
end
