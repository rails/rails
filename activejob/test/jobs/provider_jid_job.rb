# frozen_string_literal: true

require_relative '../support/job_buffer'

class ProviderJidJob < ActiveJob::Base
  def perform
    JobBuffer.add("Provider Job ID: #{provider_job_id}")
  end
end
