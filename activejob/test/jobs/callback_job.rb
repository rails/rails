# frozen_string_literal: true

class CallbackJob < ActiveJob::Base
  before_perform ->(job) { job.history << "CallbackJob ran before_perform" }
  after_perform ->(job) { job.history << "CallbackJob ran after_perform" }

  before_enqueue ->(job) { job.history << "CallbackJob ran before_enqueue" }
  after_enqueue ->(job) { job.history << "CallbackJob ran after_enqueue" }

  around_perform do |job, block|
    job.history << "CallbackJob ran around_perform_start"
    block.call
    job.history << "CallbackJob ran around_perform_stop"
  end

  around_enqueue do |job, block|
    job.history << "CallbackJob ran around_enqueue_start"
    block.call
    job.history << "CallbackJob ran around_enqueue_stop"
  end

  def perform(person = "david")
    # NOTHING!
  end

  def history
    @history ||= []
  end
end
