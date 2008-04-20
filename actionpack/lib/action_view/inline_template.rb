module ActionView #:nodoc:
  class InlineTemplate < Template #:nodoc:
    
    def initialize(view, source, locals = {}, type = nil)
      @view = view
      @finder = @view.finder
      
      @source = source
      @extension = type
      @locals = locals || {}
      
      @handler = self.class.handler_class_for_extension(@extension).new(@view)
    end
    
    def method_key
      @source
    end
    
  end
end
