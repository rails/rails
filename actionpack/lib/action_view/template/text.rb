module ActionView #:nodoc:
  class TextTemplate < String #:nodoc:

    def initialize(string, content_type = Mime[:html])
      super(string.to_s)
      @content_type = Mime[content_type]
    end

    def identifier() self end
    
    def render(*) self end
    
    def mime_type() @content_type end
      
    def partial?() false end
  end
end
