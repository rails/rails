
module ActionView #:nodoc:
  class SafeBuffer < String
    def <<(value)
      if value.html_safe?
        super(value)
      else
        super(CGI.escapeHTML(value))
      end
    end

    def concat(value)
      self << value
    end

    def html_safe?
      true
    end

    def html_safe!
      self
    end

    def to_s
      self
    end
  end
end