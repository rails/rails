# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/object/as_tags"

class AsTagsTest < ActiveSupport::TestCase
  def test_empty_string
    assert_equal [], "".as_tags
  end

  def test_empty_array
    assert_equal [], [].as_tags
  end

  def test_false
    assert_equal [], false.as_tags
  end

  def test_nil
    assert_equal [], nil.as_tags
  end

  def test_string
    assert_equal ["bold"], "bold".as_tags
  end

  def test_symbol
    assert_equal ["bold"], :bold.as_tags
  end

  def test_simple_array
    assert_equal ["bold", "123", "red"], [:bold, false, nil, "", 123, "red"].as_tags
  end

  def test_simple_hash
    assert_equal ["bold", "red"], { bold: true, green: false, red: true, false => true }.as_tags
  end

  def test_array_with_options_hash
    assert_equal ["bold", "red"], [:bold, { red: true, green: false }].as_tags
  end

  def test_array_key
    assert_equal ["bold", "red"], { ["bold", "red"] => true }.as_tags
  end

  def test_varied
    is_good = false
    is_emergency = true

    assert_equal ["alert", "red", "bold", "flashing"], arguments_to_tags(
      "alert",
      "",
      [false, nil],
      green: is_good,
      red: !is_good,
      [:bold, "flashing"] => is_emergency
    )
  end

  private
    def arguments_to_tags(*args)
      args.as_tags
    end
end
