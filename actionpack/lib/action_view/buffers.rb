require 'active_support/core_ext/string/output_safety'

module ActionView
  class OutputBuffer < ActiveSupport::SafeBuffer #:nodoc:
    def initialize(*)
      super
    end

    def <<(value)
      return self if value.nil?
      super(value.to_s)
    end
    alias :append= :<<

    def safe_concat(value)
      return self if value.nil?
      super(value.to_s)
    end
    alias :safe_append= :safe_concat
  end
end
