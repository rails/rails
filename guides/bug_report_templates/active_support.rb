# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "activesupport"
  # If you want to test against edge Rails replace the previous line with this:
  # gem "activesupport", github: "rails/rails", branch: "main"
end

require "active_support/core_ext/object/blank"
require "minitest/autorun"

class BugTest < Minitest::Test
  def test_stuff
    assert_predicate "zomg", :present?
    refute_predicate "zomg", :blank?

    refute_predicate "", :present?
    assert_predicate "", :blank?
  end
end
