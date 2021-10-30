# frozen_string_literal: true

require_relative "../support/job_buffer"

class MultipleKwargsJob < ActiveJob::Base
  def perform(argument1:, argument2: nil)
    JobBuffer.add("Job with argument1: #{argument1}, argument2: #{argument2}")
  end
end
