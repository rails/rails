# frozen_string_literal: true

require "test_helper"

class ActionText::StrictLoadingTest < ActiveSupport::TestCase
  class MessageWithStrictLoading < Message
    self.strict_loading_by_default = true

    has_rich_text :strict_loading_content
  end

  class MessageWithFooter < MessageWithStrictLoading
    has_rich_text :footer, strict_loading: false
  end

  test "has_rich_text reads strict_loading: option from strict_loading_by_default" do
    MessageWithStrictLoading.create! strict_loading_content: "ignored"

    assert_raises ActiveRecord::StrictLoadingViolationError do
      MessageWithStrictLoading.all.map(&:strict_loading_content)
    end

    MessageWithStrictLoading.with_rich_text_strict_loading_content.map(&:strict_loading_content)
  end

  test "pre-loading the association does not raise a StrictLoadingViolationError" do
    MessageWithStrictLoading.create! strict_loading_content: "ignored"

    records = MessageWithStrictLoading.with_rich_text_strict_loading_content.all

    assert_nothing_raised do
      records.map(&:strict_loading_content)
    end
  end

  test "has_rich_text accepts strict_loading: overrides" do
    MessageWithFooter.create! footer: "ignored"

    records = MessageWithFooter.all

    assert_nothing_raised do
      records.map(&:footer)
    end
  end
end
