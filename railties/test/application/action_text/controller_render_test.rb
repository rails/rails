# frozen_string_literal: true

require "isolation/abstract_unit"
require "application/action_text_integration_test_helper"

module ApplicationTests
  class ActionText::ControllerRenderTest < ActionDispatch::IntegrationTest
    include ActiveSupport::Testing::Isolation

    test "uses current request environment" do
      Dir.chdir(app_path) do
        require "#{app_path}/config/environment"

        blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
        message = Message.create!(content: ActionText::Content.new.append_attachables(blob))

        host! "loocalhoost"
        get message_path(message)
        assert_select "#content img" do |imgs|
          imgs.each { |img| assert_match %r"//loocalhoost/", img["src"] }
        end
      end
    end

    test "renders as HTML when the request format is not HTML" do
      Dir.chdir(app_path) do
        require "#{app_path}/config/environment"

        blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
        message = Message.create!(content: ActionText::Content.new.append_attachables(blob))

        host! "loocalhoost"
        get message_path(message, format: :json)

        content = ActionText.html_document_fragment_class.parse(response.parsed_body["content"])
        assert_select content, "img:match('src', ?)", %r"//loocalhoost/.+/racecar"
      end
    end

    test "renders Trix with content attachment as HTML when the request format is not HTML" do
      Dir.chdir(app_path) do
        require "#{app_path}/config/environment"

        alice = Person.create(name: "Alice")
        message_with_person_attachment = Message.create(subject: "A message to Alice")
        message_with_person_attachment.content = ActionText::Content.new.append_attachables(alice)
        message_with_person_attachment.save!

        get edit_message_path(message_with_person_attachment, format: :json)

        form_html = response.parsed_body["form"]
        assert_match %r" class=\S+mentionable-person\b", form_html
      end
    end

    test "resolves partials when controller is namespaced" do
      Dir.chdir(app_path) do
        require "#{app_path}/config/environment"

        blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
        message = Message.create!(content: ActionText::Content.new.append_attachables(blob))

        get admin_message_path(message)

        assert_select "#content-html .trix-content .attachment--jpg"
      end
    end

    test "resolves ActionText::Attachable based on their to_attachable_partial_path" do
      Dir.chdir(app_path) do
        require "#{app_path}/config/environment"

        alice = Person.create(name: "Alice")
        Message.create!(subject: "A message to Alice", content: ActionText::Content.new.append_attachables(alice))

        get messages_path

        assert_select ".mentioned-person", text: alice.name
      end
    end

    test "resolves missing ActionText::Attachable based on their to_missing_attachable_partial_path" do
      Dir.chdir(app_path) do
        require "#{app_path}/config/environment"

        alice = Person.create(name: "Alice")
        Message.create!(subject: "A message to Alice", content: ActionText::Content.new.append_attachables(alice))
        alice.destroy!

        get messages_path

        assert_select ".missing-attachable", text: "Missing person"
      end
    end
  end
end
