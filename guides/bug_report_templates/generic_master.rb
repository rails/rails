# frozen_string_literal: true

require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem 'rails', github: 'rails/rails'
end

require 'active_support'
require 'active_support/core_ext/object/blank'
require 'minitest/autorun'

class BugTest < Minitest::Test
  def test_stuff
    assert 'zomg'.present?
    refute ''.present?
  end
end
