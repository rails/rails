require 'active_support/core_ext/string/output_safety'

module ActionView
  class OutputFlow
    attr_reader :content

    def initialize
      @content = Hash.new { |h,k| h[k] = ActiveSupport::SafeBuffer.new }
    end

    def get(key)
      @content[key]
    end

    def set(key, value)
      @content[key] = (ActiveSupport::SafeBuffer.new << value)
    end

    def append(key, value)
      @content[key] << value
    end
  end

  class StreamingFlow < OutputFlow
    def initialize(view, fiber)
      @view    = view
      @parent  = nil
      @child   = view.output_buffer
      @content = view._view_flow.content
      @fiber   = fiber
      @root    = Fiber.current.object_id
    end

    # Try to get an stored content. If the content
    # is not available and we are inside the layout
    # fiber, we set that we are waiting for the given
    # key and yield.
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

    # Set the contents for the given key. This is called
    # by provides and resumes back to the fiber if it is
    # the key it is waiting for.
    def set(key, value)
      super
      @fiber.resume if @waiting_for == key
    end

    private

    def inside_fiber?
      Fiber.current.object_id != @root
    end
  end
end