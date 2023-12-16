# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "rails"
  # If you want to test against edge Rails replace the previous line with this:
  # gem "rails", github: "rails/rails", branch: "main"
end

require "minitest/autorun"
require "action_view"

class BugTest < ActionView::TestCase
  helper do
    def upcase(value)
      value.upcase
    end
  end

  def test_stuff
    render inline: <<~ERB, locals: { key: "value" }
      <p><%= upcase(key) %></p>
    ERB

    element = rendered.html.at("p")

    assert_equal element.text, "VALUE"
  end
end
