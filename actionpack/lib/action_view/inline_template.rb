module ActionView #:nodoc:
  class InlineTemplate #:nodoc:
    include Renderable

    def initialize(view, source, locals = {}, type = nil)
      @view = view

      @source = source
      @extension = type
      @locals = locals || {}

      @method_key = @source
      @handler = Template.handler_class_for_extension(@extension).new(@view)
    end
  end
end
