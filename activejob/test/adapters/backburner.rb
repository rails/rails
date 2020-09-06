# frozen_string_literal: true

require 'support/backburner/inline'

ActiveJob::Base.queue_adapter = :backburner
