# frozen_string_literal: true

require "active_support/structured_event_subscriber"

module Rails
  class StructuredEventSubscriber < ActiveSupport::StructuredEventSubscriber # :nodoc:
    self.event_namespace = "rails"

    def deprecation(event)
      emit_event("rails.deprecation",
        message: event.payload[:message],
        callstack: event.payload[:callstack],
        gem_name: event.payload[:gem_name],
        deprecation_horizon: event.payload[:deprecation_horizon],
      )
    end
  end
end

Rails::StructuredEventSubscriber.attach_to :rails
