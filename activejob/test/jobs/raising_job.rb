# frozen_string_literal: true

class RaisingJob < ActiveJob::Base
  MyError = Class.new(StandardError)

  retry_on(MyError, attempts: 2)

  def perform(error = 'RaisingJob::MyError')
    raise error.constantize
  end
end
