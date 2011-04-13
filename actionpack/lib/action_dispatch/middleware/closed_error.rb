module ActionDispatch
  class ClosedError < StandardError #:nodoc:
    def initialize(kind)
      super "Cannot modify #{kind} because it was closed. This means it was already streamed back to the client or converted to HTTP headers."
    end
  end
end
