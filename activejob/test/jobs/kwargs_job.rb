require_relative "../support/job_buffer"

class KwargsJob < ActiveJob::Base
  def perform(argument: 1)
    JobBuffer.add("Job with argument: #{argument}")
  end
end
