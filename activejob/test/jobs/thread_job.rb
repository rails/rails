# frozen_string_literal: true

class ThreadJob < ActiveJob::Base
  class << self
    attr_accessor :thread

    def latch
      @latch ||= Concurrent::CountDownLatch.new
    end

    def test_latch
      @test_latch ||= Concurrent::CountDownLatch.new
    end
  end

  def perform
    Thread.current[:job_ran] = true
    self.class.thread = Thread.current
    self.class.latch.count_down
    self.class.test_latch.wait
  end
end
