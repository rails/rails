# frozen_string_literal: true

require "test_helper"

class ActionText::PurgeLaterTest < ActiveJob::TestCase
  test "doesn't delete the files" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    message = Message.create!(content: ActionText::Content.new.append_attachables(blob))
    assert_equal 1, message.content.body.attachables.size
    assert_equal 1, message.content.embeds.size
    message.update!(content: "")
    perform_enqueued_jobs
    assert_equal 0, message.content.body.attachables.size
    assert_equal 1, message.content.embeds.size
    assert_nothing_raised { blob.download }
  end
end
