# frozen_string_literal: true

require_relative '../support/job_buffer'
require 'active_support/time'

class TimezoneDependentJob < ActiveJob::Base
  def perform(now)
    now = now.in_time_zone
    new_year = localtime(2018, 1, 1)

    if now >= new_year
      JobBuffer.add('Happy New Year!')
    else
      JobBuffer.add("Just #{(new_year - now).div(3600)} hours to go")
    end
  end

  private
    def localtime(*args)
      Time.zone ? Time.zone.local(*args) : Time.utc(*args)
    end
end
