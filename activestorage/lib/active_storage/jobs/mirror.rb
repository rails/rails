# frozen_string_literal: true

require "active_support/core_ext/object/try"

module ActiveStorage
  module Jobs
    module Mirror
      extend ActiveSupport::Concern
      # Provides asynchronous mirroring of directly-uploaded blobs.

      included do
        queue_as { ActiveStorage.queues[:mirror] }

        discard_on ActiveStorage::FileNotFoundError
        retry_on ActiveStorage::IntegrityError, attempts: 10, wait: :polynomially_longer

        def perform(key, checksum:)
          self.class.blob_class.service.try(:mirror, key, checksum: checksum)
        end
      end
    end
  end
end
