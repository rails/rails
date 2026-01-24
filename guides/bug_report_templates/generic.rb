# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "rails"
  # If you want to test against edge Rails replace the previous line with this:
  # gem "rails", github: "rails/rails", branch: "main"
end

require "active_support"
require "active_support/core_ext/object/blank"
require "minitest/autorun"

class BugTest < ActiveSupport::TestCase
  def test_stuff
    assert "zomg".present?
    assert_not "".present?
  end
end
