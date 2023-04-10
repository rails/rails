# frozen_string_literal: true

class ArgumentsRoundTripJob < ActiveJob::Base
  def perform(*arguments)
    JobBuffer.add(arguments)
  end
end
