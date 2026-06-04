# frozen_string_literal: true

CallbackMailerError = Class.new(StandardError)
class CallbackMailer < ActionMailer::Base
  cattr_accessor :rescue_from_error
  cattr_accessor :after_deliver_instance
  cattr_accessor :around_deliver_instance
  cattr_accessor :abort_before_action
  cattr_accessor :abort_before_deliver
  cattr_accessor :around_handles_error
  cattr_accessor :deliver_callback_log

  rescue_from CallbackMailerError do |error|
    @@rescue_from_error = error
  end

  before_action do
    self.response_body = "abort" if @@abort_before_action
  end

  before_deliver do
    throw :abort if @@abort_before_deliver
  end

  before_deliver(only: :test_message) do
    CallbackMailer.deliver_callback_log << :before_only
  end

  before_deliver(except: :test_message) do
    CallbackMailer.deliver_callback_log << :before_except
  end

  after_deliver do
    @@after_deliver_instance = self
  end

  after_deliver(only: :test_message) do
    CallbackMailer.deliver_callback_log << :after_only
  end

  after_deliver(except: :test_message) do
    CallbackMailer.deliver_callback_log << :after_except
  end

  around_deliver do |mailer, block|
    @@around_deliver_instance = self
    block.call
  rescue StandardError
    raise unless @@around_handles_error
  end

  around_deliver(only: :test_message) do |mailer, block|
    CallbackMailer.deliver_callback_log << :around_only_before
    block.call
    CallbackMailer.deliver_callback_log << :around_only_after
  end

  around_deliver(except: :test_message) do |mailer, block|
    CallbackMailer.deliver_callback_log << :around_except_before
    block.call
    CallbackMailer.deliver_callback_log << :around_except_after
  end

  def test_message(*)
    mail(from: "test-sender@test.com", to: "test-receiver@test.com", subject: "Test Subject", body: "Test Body")
  end

  def another_test_message(*)
    mail(from: "test-sender@test.com", to: "test-receiver@test.com", subject: "Another Test Subject", body: "Another Test Body")
  end

  def test_raise_action
    raise CallbackMailerError, "boom action processing"
  end
end
