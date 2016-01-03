require 'active_support/core_ext/string/output_safety'

module ActionView
  class OutputBuffer < ActiveSupport::SafeBuffer #:nodoc:
    def initialize(*)
      super
      encode!
    end

    def <<(value)
      return self if value.nil?
      super(value.to_s)
    end
    alias :append= :<<

    def safe_expr_append=(val)
      return self if val.nil?
      safe_concat val.to_s
    end

    alias :safe_append= :safe_concat
  end

  class StreamingBuffer #:nodoc:
    def initialize(block)
      @block = block
    end

    def <<(value)
      value = value.to_s
      value = ERB::Util.h(value) unless value.html_safe?
      @block.call(value)
    end
    alias :concat  :<<
    alias :append= :<<

    def safe_concat(value)
      @block.call(value.to_s)
    end
    alias :safe_append= :safe_concat

    def html_safe?
      true
    end

    def html_safe
      self
    end
  end
end
