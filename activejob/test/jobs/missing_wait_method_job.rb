# frozen_string_literal: true

class MissingWaitMethodJob < ActiveJob::Base
  retry_on StandardError, wait: :missing_wait

  def perform
    raise "boom"
  end
end
