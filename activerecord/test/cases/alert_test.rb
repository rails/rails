# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/translation"

class AssociationsTest < ActiveRecord::TestCase
  fixtures :authors

  def test_without_error_messages
    assert_equal "", authors(:david).alert
  end

  def test_with_one_error
    author = authors(:david)
    author.name = nil
    assert_not author.valid?
    assert_equal "Name can’t be blank", author.alert
  end

  def test_with_two_errors
    translation = Translation.new
    assert_not translation.valid?
    assert_equal(
      "Locale can’t be blank, Key can’t be blank, and Value can’t be blank",
      translation.alert
    )
  end
end
