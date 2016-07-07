require 'active_support/core_ext/string/output_safety'

module ActionView
  class OutputFlow #:nodoc:
    attr_reader :content

    def initialize
      @content = Hash.new { |h,k| h[k] = ActiveSupport::SafeBuffer.new }
    end

    # Called by _layout_for to read stored values.
    def get(key)
      @content[key]
    end

    # Called by each renderer object to set the layout contents.
    def set(key, value)
      @content[key] = ActiveSupport::SafeBuffer.new(value)
    end

    # Called by content_for
    def append(key, value)
      @content[key] << value
    end
    alias_method :append!, :append

  end

  class StreamingFlow < OutputFlow #:nodoc:
    def initialize(view, fiber)
      @view    = view
      @parent  = nil
      @child   = view.output_buffer
      @content = view.view_flow.content
      @fiber   = fiber
      @root    = Fiber.current.object_id
    end

    # Try to get stored content. If the content
    # is not available and we're inside the layout fiber,
    # then it will begin waiting for the given key and yield.
    def get(key)
      return super if @content.key?(key)

      if inside_fiber?
        view = @view

        begin
          @waiting_for = key
          view.output_buffer, @parent = @child, view.output_buffer
          Fiber.yield
        ensure
          @waiting_for = nil
          view.output_buffer, @child = @parent, view.output_buffer
        end
      end

      super
    end

    # Appends the contents for the given key. This is called
    # by providing and resuming back to the fiber,
    # if that's the key it's waiting for.
    def append!(key, value)
      super
      @fiber.resume if @waiting_for == key
    end

    private

    def inside_fiber?
      Fiber.current.object_id != @root
    end
  end
end
