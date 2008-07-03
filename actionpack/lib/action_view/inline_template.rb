module ActionView #:nodoc:
  class InlineTemplate #:nodoc:
    include Renderer

    def initialize(view, source, locals = {}, type = nil)
      @view = view

      @source = source
      @extension = type
      @locals = locals || {}

      @method_key = @source
      @handler = Base.handler_class_for_extension(@extension).new(@view)
    end
  end
end
