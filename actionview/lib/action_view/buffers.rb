# frozen_string_literal: true

require "active_support/core_ext/string/output_safety"

module ActionView
  # Used as a buffer for views
  #
  # The main difference between this and ActiveSupport::SafeBuffer
  # is for the methods `<<` and `safe_expr_append=` the inputs are
  # checked for nil before they are assigned and `to_s` is called on
  # the input. For example:
  #
  #   obuf = ActionView::OutputBuffer.new "hello"
  #   obuf << 5
  #   puts obuf # => "hello5"
  #
  #   sbuf = ActiveSupport::SafeBuffer.new "hello"
  #   sbuf << 5
  #   puts sbuf # => "hello\u0005"
  #
  class OutputBuffer # :nodoc:
    def initialize(buffer = "")
      @buffer = String.new(buffer)
      @buffer.encode!
    end

    delegate :length, :blank?, :encoding, :encode!, :force_encoding, to: :@buffer

    def to_s
      @buffer.html_safe
    end
    alias_method :html_safe, :to_s

    def to_str
      @buffer.dup
    end

    def html_safe?
      true
    end

    def <<(value)
      unless value.nil?
        value = value.to_s
        @buffer << if value.html_safe?
          value
        else
          CGI.escapeHTML(value)
        end
      end
      self
    end
    alias :append= :<<

    def safe_concat(value)
      @buffer << value
      self
    end
    alias :safe_append= :safe_concat

    def safe_expr_append=(val)
      return self if val.nil?
      @buffer << val.to_s
      self
    end

    def initialize_copy(other)
      @buffer = other.to_str
    end

    # Don't use this
    def slice!(range)
      @buffer.slice!(range)
    end

    def ==(other)
      other.class == self.class && @buffer == other.to_str
    end
  end

  class StreamingBuffer # :nodoc:
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
