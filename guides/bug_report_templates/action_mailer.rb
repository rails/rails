# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "rails"
  # If you want to test against edge Rails replace the previous line with this:
  # gem "rails", github: "rails/rails", branch: "main"
end

require "action_mailer/railtie"

class TestMailer < ActionMailer::Base
  def hello_world
    @message = "Hello, world"

    mail from: "test@example.com", to: "user@example.com" do |format|
      format.html { render inline: "<h1><%= @message %></h1>" }
      format.text { render inline: "<%= @message %>" }
    end
  end
end

require "minitest/autorun"

class BugTest < ActionMailer::TestCase
  test "renders HTML and Text body" do
    email = TestMailer.hello_world

    email.deliver_now

    assert_dom_email do
      assert_dom "h1", text: "Hello, world"
    end
    assert_includes email.text_part.body, "Hello, world"
  end
end
