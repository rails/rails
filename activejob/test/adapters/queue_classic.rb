# frozen_string_literal: true

require 'support/queue_classic/inline'
ActiveJob::Base.queue_adapter = :queue_classic
