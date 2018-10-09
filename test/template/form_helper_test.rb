# frozen_string_literal: true

require 'test_helper'

class ActionText::FormHelperTest < ActionView::TestCase
  tests ActionText::TagHelper

  def form_with(*)
    @output_buffer = super
  end

  test "rich_text_area doesn't raise when attributes don't exist in the model" do
    assert_nothing_raised do
      form_with(model: Message.new, scope: :message, id: "create-message") do |form|
        form.rich_text_area(:not_an_attribute)
      end
    end

    assert_match "message[not_an_attribute]", output_buffer
  end
end
