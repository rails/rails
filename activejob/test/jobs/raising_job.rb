# frozen_string_literal: true

class RaisingJob < ActiveJob::Base
  MyError = Class.new(StandardError)

  retry_on(MyError, attempts: 2)

  def perform
    raise MyError
  end
end
