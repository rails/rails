# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  # Activate the gem you are reporting the issue against.
  gem "rails", "~> 7.1.0"
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
