# frozen_string_literal: true

module ActiveRecord
  class DestroyAsyncError < StandardError
  end

  # Job to destroy  a record  in background.
  class DestroyAsyncJob < ActiveJob::Base
    queue_as { ActiveRecord::Base.queues[:destroy] }

    discard_on ActiveJob::DeserializationError

    def perform(
      model_name: nil, id: nil
    )
      model = model_name.constantize
      begin
        model.find(id).destroy
      rescue ActiveRecord::RecordNotFound
        nil
      end
    end
  end
end
