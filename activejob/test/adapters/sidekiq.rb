# frozen_string_literal: true

require "sidekiq/testing/inline"
ActiveJob::Base.queue_adapter = :sidekiq
