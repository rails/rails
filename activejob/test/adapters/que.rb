# frozen_string_literal: true

require "support/que/inline"

ActiveJob::Base.queue_adapter = :que
Que.mode = :sync
