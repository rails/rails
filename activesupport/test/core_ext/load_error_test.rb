# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/load_error"

class TestLoadError < ActiveSupport::TestCase
  def test_with_require
    assert_raise(LoadError) { require "no_this_file_don't_exist" }
  end

  def test_with_load
    assert_raise(LoadError) { load "nor_does_this_one" }
  end

  def test_path
    load "nor/this/one.rb"
  rescue LoadError => e
    assert_equal "nor/this/one.rb", e.path
  end

  def test_is_missing_with_nil_path
    error = LoadError.new(nil)
    assert_nothing_raised { error.is_missing?("anything") }
  end
end
