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
      @raw_buffer = String.new(buffer)
      @raw_buffer.encode!
    end

    delegate :length, :empty?, :blank?, :encoding, :encode!, :force_encoding, to: :@raw_buffer

    def to_s
      @raw_buffer.html_safe
    end
    alias_method :html_safe, :to_s

    def to_str
      @raw_buffer.dup
    end

    def html_safe?
      true
    end

    def <<(value)
      unless value.nil?
        value = value.to_s
        @raw_buffer << if value.html_safe?
          value
        else
          ERB::Util.unwrapped_html_escape(value)
        end
      end
      self
    end
    alias :concat :<<
    alias :append= :<<

    def safe_concat(value)
      @raw_buffer << value
      self
    end
    alias :safe_append= :safe_concat

    def safe_expr_append=(val)
      return self if val.nil?
      @raw_buffer << val.to_s
      self
    end

    def initialize_copy(other)
      @raw_buffer = other.to_str
    end

    def capture(*args)
      new_buffer = +""
      old_buffer, @raw_buffer = @raw_buffer, new_buffer
      yield(*args)
      new_buffer.html_safe
    ensure
      @raw_buffer = old_buffer
    end

    def ==(other)
      other.class == self.class && @raw_buffer == other.to_str
    end

    def raw
      RawOutputBuffer.new(self)
    end

    attr_reader :raw_buffer
  end

  class RawOutputBuffer # :nodoc:
    def initialize(buffer)
      @buffer = buffer
    end

    def <<(value)
      unless value.nil?
        @buffer.raw_buffer << value.to_s
      end
    end

    def raw
      self
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

    def capture
      buffer = +""
      old_block, @block = @block, ->(value) { buffer << value }
      yield
      buffer.html_safe
    ensure
      @block = old_block
    end

    def html_safe?
      true
    end

    def html_safe
      self
    end

    def raw
      RawStreamingBuffer.new(self)
    end

    attr_reader :block
  end

  class RawStreamingBuffer # :nodoc:
    def initialize(buffer)
      @buffer = buffer
    end

    def <<(value)
      unless value.nil?
        @buffer.block.call(value.to_s)
      end
    end

    def raw
      self
    end
  end
end
