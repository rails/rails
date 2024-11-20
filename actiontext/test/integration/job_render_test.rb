# frozen_string_literal: true

require "test_helper"

class ActionText::JobRenderTest < ActiveJob::TestCase
  include Rails::Dom::Testing::Assertions::SelectorAssertions

  test "uses app default_url_options" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    message = Message.create!(content: ActionText::Content.new.append_attachables(blob))

    Dir.mktmpdir do |dir|
      file = File.join(dir, "broadcast.html")

      BroadcastJob.perform_later(file, message)

      with_default_url_options(host: "foo.example.com", port: 9001) do
        perform_enqueued_jobs
      end

      rendered = ActionText.html_document_fragment_class.parse(File.read(file))
      assert_select rendered, "img:match('src', ?)", %r"//foo.example.com:9001/.+/racecar"
    end
  end

  private
    def with_default_url_options(default_url_options)
      original_default_url_options = Dummy::Application.default_url_options
      Dummy::Application.default_url_options = default_url_options
      yield
    ensure
      Dummy::Application.default_url_options = original_default_url_options
    end
end
