module ActionView #:nodoc:
  class TextTemplate < String #:nodoc:
    
    def render(*) self end
    
    def mime_type() Mime::HTML end
  end
end
