# frozen_string_literal: true

require "active_support/structured_event_subscriber"

module ActiveStorage
  class StructuredEventSubscriber < ActiveSupport::StructuredEventSubscriber # :nodoc:
    def service_upload(event)
      payload = {
        key: event.payload[:key],
        checksum: event.payload[:checksum],
        duration_ms: event.duration.round(2),
      }
      payload[:exception] = event.payload[:exception] if event.payload[:exception]
      emit_event("active_storage.service_upload", payload)
    end

    def service_download(event)
      payload = {
        key: event.payload[:key],
        duration_ms: event.duration.round(2),
      }
      payload[:exception] = event.payload[:exception] if event.payload[:exception]
      emit_event("active_storage.service_download", payload)
    end

    def service_streaming_download(event)
      payload = {
        key: event.payload[:key],
        duration_ms: event.duration.round(2),
      }
      payload[:exception] = event.payload[:exception] if event.payload[:exception]
      emit_event("active_storage.service_streaming_download", payload)
    end

    def preview(event)
      payload = {
        key: event.payload[:key],
        duration_ms: event.duration.round(2),
      }
      payload[:exception] = event.payload[:exception] if event.payload[:exception]
      emit_event("active_storage.preview", payload)
    end

    def service_delete(event)
      payload = {
        key: event.payload[:key],
        duration_ms: event.duration.round(2),
      }
      payload[:exception] = event.payload[:exception] if event.payload[:exception]
      emit_event("active_storage.service_delete", payload)
    end

    def service_delete_prefixed(event)
      payload = {
        prefix: event.payload[:prefix],
        duration_ms: event.duration.round(2),
      }
      payload[:exception] = event.payload[:exception] if event.payload[:exception]
      emit_event("active_storage.service_delete_prefixed", payload)
    end

    def service_exist(event)
      payload = {
        key: event.payload[:key],
        exist: event.payload[:exist],
        duration_ms: event.duration.round(2),
      }
      payload[:exception] = event.payload[:exception] if event.payload[:exception]
      emit_debug_event("active_storage.service_exist", payload)
    end
    debug_only :service_exist

    def service_url(event)
      payload = {
        key: event.payload[:key],
        url: event.payload[:url],
        duration_ms: event.duration.round(2),
      }
      payload[:exception] = event.payload[:exception] if event.payload[:exception]
      emit_debug_event("active_storage.service_url", payload)
    end
    debug_only :service_url

    def service_mirror(event)
      payload = {
        key: event.payload[:key],
        checksum: event.payload[:checksum],
        duration_ms: event.duration.round(2),
      }
      payload[:exception] = event.payload[:exception] if event.payload[:exception]
      emit_debug_event("active_storage.service_mirror", payload)
    end
    debug_only :service_mirror
  end
end

ActiveStorage::StructuredEventSubscriber.attach_to :active_storage
