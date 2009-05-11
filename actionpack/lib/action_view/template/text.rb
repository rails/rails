module ActionView #:nodoc:
  class TextTemplate < String #:nodoc:

    def identifier() self end
    
    def render(*) self end
    
    def mime_type() Mime::HTML end
      
    def partial?() false end
  end
end
