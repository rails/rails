# frozen_string_literal: true

class AbortBeforeEnqueueJob < ActiveJob::Base
  MyError = Class.new(StandardError)

  before_enqueue :throw_or_raise
  before_perform { throw(:abort) }

  def perform
    raise "This should never be called"
  end

  def throw_or_raise
    if (arguments.first || :abort) == :abort
      throw(:abort)
    else
      raise(MyError)
    end
  end
end
