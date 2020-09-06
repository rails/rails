# frozen_string_literal: true

require 'sucker_punch/testing/inline'
ActiveJob::Base.queue_adapter = :sucker_punch
