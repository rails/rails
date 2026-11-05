# frozen_string_literal: true

require "active_support/structured_event_subscriber"

module ActiveStorage
  class StructuredEventSubscriber < ActiveSupport::StructuredEventSubscriber # :nodoc:
    def service_upload(event)
      emit_event("active_storage.service_upload",
        key: event.payload[:key],
        checksum: event.payload[:checksum],
        duration_ms: event.duration.round(2),
      )
    end

    def service_download(event)
      emit_event("active_storage.service_download",
        key: event.payload[:key],
        duration_ms: event.duration.round(2),
      )
    end

    def service_streaming_download(event)
      emit_event("active_storage.service_streaming_download",
        key: event.payload[:key],
        duration_ms: event.duration.round(2),
      )
    end

    def preview(event)
      emit_event("active_storage.preview",
        key: event.payload[:key],
        duration_ms: event.duration.round(2),
      )
    end

    def service_delete(event)
      emit_event("active_storage.service_delete",
        key: event.payload[:key],
        duration_ms: event.duration.round(2),
      )
    end

    def service_delete_prefixed(event)
      emit_event("active_storage.service_delete_prefixed",
        prefix: event.payload[:prefix],
        duration_ms: event.duration.round(2),
      )
    end

    def service_exist(event)
      emit_debug_event("active_storage.service_exist",
        key: event.payload[:key],
        exist: event.payload[:exist],
        duration_ms: event.duration.round(2),
      )
    end
    debug_only :service_exist

    def service_url(event)
      emit_debug_event("active_storage.service_url",
        key: event.payload[:key],
        url: event.payload[:url],
        duration_ms: event.duration.round(2),
      )
    end
    debug_only :service_url

    def service_mirror(event)
      emit_debug_event("active_storage.service_mirror",
        key: event.payload[:key],
        checksum: event.payload[:checksum],
        duration_ms: event.duration.round(2),
      )
    end
    debug_only :service_mirror
  end
end

ActiveStorage::StructuredEventSubscriber.attach_to :active_storage
