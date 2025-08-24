# frozen_string_literal: true

CallbackMailerError = Class.new(StandardError)
class CallbackMailer < ActionMailer::Base
  cattr_accessor :rescue_from_error
  cattr_accessor :after_deliver_instance
  cattr_accessor :around_deliver_instance
  cattr_accessor :abort_before_deliver
  cattr_accessor :around_handles_error
  cattr_accessor :callback_with_only_option
  cattr_accessor :callback_with_except_option

  rescue_from CallbackMailerError do |error|
    @@rescue_from_error = error
  end

  before_deliver do
    throw :abort if @@abort_before_deliver
  end

  after_deliver do
    @@after_deliver_instance = self
  end

  before_deliver only: :test_message do
    @@callback_with_only_option << action_name
  end

  before_deliver except: [:test_message, :non_existent_action] do
    @@callback_with_except_option << action_name
  end

  around_deliver do |mailer, block|
    @@around_deliver_instance = self
    block.call
  rescue StandardError
    raise unless @@around_handles_error
  end

  def test_message(*)
    mail(from: "test-sender@test.com", to: "test-receiver@test.com", subject: "Test Subject", body: "Test Body")
  end

  def test_raise_action
    raise CallbackMailerError, "boom action processing"
  end
end
