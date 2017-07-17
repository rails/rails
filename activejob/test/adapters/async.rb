# frozen_string_literal: true

ActiveJob::Base.queue_adapter = :async
ActiveJob::Base.queue_adapter.immediate = true
