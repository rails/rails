# frozen_string_literal: true

require 'support/sneakers/inline'
ActiveJob::Base.queue_adapter = :sneakers
