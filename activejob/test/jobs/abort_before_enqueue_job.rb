# frozen_string_literal: true

class AbortBeforeEnqueueJob < ActiveJob::Base
  MyError = Class.new(StandardError)

  before_enqueue :throw_or_raise
  after_enqueue { self.flag = 'after_enqueue' }
  before_perform { throw(:abort) }
  after_perform { self.flag = 'after_perform' }

  attr_accessor :flag

  def perform
    raise 'This should never be called'
  end

  def throw_or_raise
    if (arguments.first || :abort) == :abort
      throw(:abort)
    else
      raise(MyError)
    end
  end
end
