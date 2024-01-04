# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "rails"
  # If you want to test against edge Rails replace the previous line with this:
  # gem "rails", github: "rails/rails", branch: "main"
end

require "active_support"
require "active_support/core_ext/object/blank"
require "minitest/autorun"

class BugTest < Minitest::Test
  def test_stuff
    assert "zomg".present?
    refute "".present?
  end
end
