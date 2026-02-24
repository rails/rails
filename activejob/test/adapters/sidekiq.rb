# frozen_string_literal: true

require "sidekiq"
if Sidekiq.respond_to? :testing! # 8.1.1
  Sidekiq.testing!(:inline)
else
  require "sidekiq/testing/inline"
end
ActiveJob::Base.queue_adapter = :sidekiq
