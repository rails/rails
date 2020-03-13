# frozen_string_literal: true

require "active_support/current_attributes"

class ActionText::Current < ActiveSupport::CurrentAttributes #:nodoc:
  # Memoizes ActionText::Content.renderer.current, the renderer for
  # the current request. The memoized render is kept on Current so it's
  # automatically reset after each request/job.
  attribute :renderer_for_current_request
end
