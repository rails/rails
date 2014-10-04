class CallbackJob < ActiveJob::Base
  before_perform ->(job) { job.history << "CallbackJob ran before_perform" }
  after_perform  ->(job) { job.history << "CallbackJob ran after_perform"  }

  before_enqueue ->(job) { job.history << "CallbackJob ran before_enqueue" }
  after_enqueue  ->(job) { job.history << "CallbackJob ran after_enqueue"  }

  around_perform :around_perform
  around_enqueue :around_enqueue


  def perform(person = "david")
    # NOTHING!
  end

  def history
    @history ||= []
  end

  # FIXME: Not sure why these can't be declared inline like before/after
  def around_perform
    history << "CallbackJob ran around_perform_start"
    yield
    history << "CallbackJob ran around_perform_stop"
  end

  def around_enqueue
    history << "CallbackJob ran around_enqueue_start"
    yield
    history << "CallbackJob ran around_enqueue_stop"
  end
end
