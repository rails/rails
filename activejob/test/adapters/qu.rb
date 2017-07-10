# frozen_string_literal: true

require "qu-immediate"

ActiveJob::Base.queue_adapter = :qu
