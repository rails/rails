# frozen_string_literal: true

require "cases/helper"
require "models/entry"
require "models/message"
require "models/comment"

class DelegatedTypeTest < ActiveRecord::TestCase
  test "create entry with message" do
    entry = Entry.create! entryable: Message.new(subject: "Hello world!")
    assert entry.message?
  end
end
