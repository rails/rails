# frozen_string_literal: true

ActiveJob::Base.queue_adapter = :resque
Resque.inline = true
