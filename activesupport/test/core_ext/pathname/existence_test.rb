# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/pathname/existence"

class PathnameExistenceTest < ActiveSupport::TestCase
  def test_existence
    existing = Pathname.new(__FILE__)
    not_existing = Pathname.new("not existing")
    assert_equal existing, existing.existence
    assert_nil not_existing.existence
  end
end
