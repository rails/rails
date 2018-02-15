# frozen_string_literal: true

require 'faktory_worker_ruby'
require 'faktory/testing'
Faktory::Testing.inline!
ActiveJob::Base.queue_adapter = :faktory
