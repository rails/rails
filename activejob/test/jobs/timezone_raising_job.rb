# frozen_string_literal: true

require_relative "../support/job_buffer"
require "active_support/time"

class TimezoneRaisingJob < ActiveJob::Base
  rescue_from(StandardError) do
    JobBuffer.add(Time.zone.name)
  end

  def perform
    raise "boom"
  end
end
