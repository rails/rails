# frozen_string_literal: true

class ActiveStorage::BaseJob < ActiveJob::Base
  queue_as { ActiveStorage.queue }
end
