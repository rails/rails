# frozen_string_literal: true

begin
  require "bundler/inline"
rescue LoadError => e
  $stderr.puts "Bundler version 1.10 or later is required. Please update your Bundler"
  raise e
end

gemfile true do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "rails", github: "rails/rails"
end

ENV["RAILS_ENV"] ||= "test"

require "action_mailer"
require "minitest/autorun"

ActionMailer::Base.delivery_method = :test

class TestMailer < ActionMailer::Base
  default to: "test@localhost",
    subject: "You have a mail",
    from: "tester@example.com"

  def test
    mail(from: "me@example.com", to: "someone@somewhere.com", subject: "Test", body: "hello world")
  end

  def welcome_email
    attachments["invoice.pdf"] = "This is test File content"
    mail(from: "me@example.com", to: "someone@somewhere.com", cc: "cc@example.com", bcc: "bcc@somewhere.com",
      reply_to: "reply_to@example.com", subject: "Welcome to My Awesome Site", charset: "UTF-8",
      mime_version: "2.0") do |format|
      format.html { render plain: "<h1>Hello world</h1>" }
      format.text { render plain: "Hello world" }
    end
  end

  def welcome(hash = {})
    headers["X-SPAM"] = "Not SPAM"
    mail({ subject: "The first email on new API!" }.merge!(hash))
  end
end

class BugTest < Minitest::Test
  def test_custom_notification
    email = TestMailer.welcome_email.deliver_now
    assert_equal(["me@example.com"],             email.from)
    assert_equal(["bcc@somewhere.com"],             email.bcc)
    assert_equal(["cc@example.com"],              email.cc)
    assert_equal("UTF-8",                          email.charset)
    assert_equal("2.0",                                 email.mime_version)
    assert_equal(["reply_to@example.com"],        email.reply_to)
    assert_equal(1, email.attachments.length)
    assert_equal("invoice.pdf", email.attachments[0].filename)
    assert_equal("This is test File content", email.attachments["invoice.pdf"].decoded)
    assert_equal "multipart/mixed", email.mime_type
    assert_equal 2, email.parts.size
    assert_equal "multipart/alternative", email.parts.first.mime_type
    assert_equal "", email.parts.first.body.to_s
    assert_equal "application/pdf", email.parts.last.mime_type
    assert_equal "This is test File content", email.parts.last.body.to_s
  end
end
