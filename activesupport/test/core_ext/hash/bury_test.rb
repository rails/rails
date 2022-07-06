# frozen_string_literal: true

# require_relative "../../abstract_unit"
require "active_support/core_ext/hash/bury"

class HashBuryTest < ActiveSupport::TestCase
  test "build a deep nested hash structure" do
    actual = Hash.bury(:conference, :tracks, :sessions, :keynote, presenter: "@tenderlove", topic: "hotwire")
    expected = { conference: { tracks: { sessions: { keynote: { presenter: "@tenderlove", topic: "hotwire" } } } } }

    assert actual.equal?(expected)
  end

  test "works with index numbers" do
    actual = Hash.bury(:a, 0, :c, 42)
    expected = { a: { 0 => { c: 42 } } }

    assert actual.equal?(expected)
  end
end
