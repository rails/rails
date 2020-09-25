# frozen_string_literal: true

require "test_helper"

class FixtureFileHelpersTest < ActiveSupport::TestCase
  def test_action_text_attachment
    message = messages(:hello_world)
    review = reviews(:hello_world)

    attachments = review.content.body.attachments

    assert_includes attachments.map(&:attachable), message
  end
end
