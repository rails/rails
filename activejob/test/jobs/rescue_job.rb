# frozen_string_literal: true

require_relative "../support/job_buffer"

class RescueJob < ActiveJob::Base
  class OtherError < StandardError; end

  rescue_from(ArgumentError) do
    JobBuffer.add("rescued from ArgumentError")
    arguments[0] = "DIFFERENT!"
    job = retry_job
    JobBuffer.add("Retried job #{job.arguments[0]}")
    job
  end

  rescue_from(ActiveJob::DeserializationError) do |e|
    JobBuffer.add("rescued from DeserializationError")
    JobBuffer.add("DeserializationError original exception was #{e.cause.class.name}")
  end

  rescue_from(NotImplementedError) do
    JobBuffer.add("rescued from NotImplementedError")
  end

  def perform(person = "david")
    case person
    when "david"
      raise ArgumentError, "Hair too good"
    when "other"
      raise OtherError, "Bad hair"
    when "rafael"
      raise NotImplementedError, "Hair is just perfect"
    else
      JobBuffer.add("performed beautifully")
    end
  end
end
