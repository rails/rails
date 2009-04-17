module ActionView #:nodoc:
  class TextTemplate < String #:nodoc:
    
    def render(*) self end
    
    def exempt_from_layout?() false end
    
  end
end
