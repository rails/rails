# Keep this file meanwhile https://github.com/rack/rack/pull/313 is not released
module ActionDispatch
  class BodyProxy
    def initialize(body, &block)
      @body, @block, @closed = body, block, false
    end

    def respond_to?(*args)
      super or @body.respond_to?(*args)
    end

    def close
      return if @closed
      @closed = true
      begin
        @body.close if @body.respond_to? :close
      ensure
        @block.call
      end
    end

    def closed?
      @closed
    end

    def method_missing(*args, &block)
      @body.__send__(*args, &block)
    end
  end
end
