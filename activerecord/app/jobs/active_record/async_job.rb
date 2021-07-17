# frozen_string_literal: true

module ActiveRecord
  # Runs an instance method from a model as an asynchronous operation,
  # without having to create a job just for that
  class AsyncJob < ActiveJob::Base
    queue_as :default

    def perform(record, method_name, *args)
      record.public_send(method_name, *args)
    end
  end
end
