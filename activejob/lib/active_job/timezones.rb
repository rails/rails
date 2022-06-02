# frozen_string_literal: true

module ActiveJob
  module Timezones # :nodoc:
    extend ActiveSupport::Concern

    included do
      around_perform do |job, block|
        Time.use_zone(job.timezone, &block)
      end
    end
  end
end
