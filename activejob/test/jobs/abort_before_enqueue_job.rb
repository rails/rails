# frozen_string_literal: true

class AbortBeforeEnqueueJob < ActiveJob::Base
  before_enqueue { throw(:abort) }

  def perform
    raise "This should never be called"
  end
end
