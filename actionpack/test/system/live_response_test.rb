# frozen_string_literal: true

require "application_system_test_case"

class LiveResponseTest < ApplicationSystemTestCase
  def setup
    ENV["RAILS_ENV"] = "test"
    visit "/streaming"
  end

  test "live response should work" do
    assert_text "hello world"
  end
end
