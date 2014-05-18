module ActiveJob

  class NotImplementedError < ::NotImplementedError #:nodoc:
  end

  class Error < ::StandardError #:nodoc:
    def initialize(message = nil)
      super(message)
    end
  end

end