# frozen_string_literal: true

require_relative "../support/job_buffer"

class ConfigurationJob < ActiveJob::Base
  def perform
    JobBuffer.add(self)
  end
end
