require 'erb'
require 'active_support/core_ext/kernel/singleton_class'

class ERB
  module Util
    HTML_ESCAPE = { '&' => '&amp;',  '>' => '&gt;',   '<' => '&lt;', '"' => '&quot;', "'" => '&#39;' }
    JSON_ESCAPE = { '&' => '\u0026', '>' => '\u003e', '<' => '\u003c', "\u2028" => '\u2028', "\u2029" => '\u2029' }
    HTML_ESCAPE_REGEXP = /[&"'><]/
    HTML_ESCAPE_ONCE_REGEXP = /["><']|&(?!([a-zA-Z]+|(#\d+));)/
    JSON_ESCAPE_REGEXP = /[\u2028\u2029&><]/u

    # A utility method for escaping HTML tag characters.
    # This method is also aliased as <tt>h</tt>.
    #
    # In your ERB templates, use this method to escape any unsafe content. For example:
    #   <%=h @person.name %>
    #
    #   puts html_escape('is a > 0 & a < 10?')
    #   # => is a &gt; 0 &amp; a &lt; 10?
    def html_escape(s)
      s = s.to_s
      if s.html_safe?
        s
      else
        s.gsub(HTML_ESCAPE_REGEXP, HTML_ESCAPE).html_safe
      end
    end

    # Aliasing twice issues a warning "discarding old...". Remove first to avoid it.
    remove_method(:h)
    alias h html_escape

    module_function :h

    singleton_class.send(:remove_method, :html_escape)
    module_function :html_escape

    # A utility method for escaping HTML without affecting existing escaped entities.
    #
    #   html_escape_once('1 < 2 &amp; 3')
    #   # => "1 &lt; 2 &amp; 3"
    #
    #   html_escape_once('&lt;&lt; Accept & Checkout')
    #   # => "&lt;&lt; Accept &amp; Checkout"
    def html_escape_once(s)
      result = s.to_s.gsub(HTML_ESCAPE_ONCE_REGEXP, HTML_ESCAPE)
      s.html_safe? ? result.html_safe : result
    end

    module_function :html_escape_once

    # A utility method for escaping HTML entities in JSON strings. Specifically, the
    # &, > and < characters are replaced with their equivilant unicode escaped form -
    # \u0026, \u003e, and \u003c. The Unicode sequences \u2028 and \u2029 are also
    # escaped as then are treated as newline characters in some JavaScript engines. 
    # These sequences has identical meaning as the original characters inside the
    # context of a JSON string, so assuming the input is a valid and well-formed
    # JSON value, the output will have equivilant meaning when parsed:
    # 
    #   json = JSON.generate({ name: "</script><script>alert('PWNED!!!')</script>"})
    #   # => "{\"name\":\"</script><script>alert('PWNED!!!')</script>\"}"
    # 
    #   json_escape(json)
    #   # => "{\"name\":\"\\u003C/script\\u003E\\u003Cscript\\u003Ealert('PWNED!!!')\\u003C/script\\u003E\"}"
    # 
    #   JSON.parse(json) == JSON.parse(json_escape(json))
    #   # => true
    # 
    # The intended use case for this method is to escape JSON strings before including
    # them inside a script tag to avoid XSS vulnerability:
    # 
    #   <script type="application/javascript">
    #     var currentUser = <%= json_escape current_user.to_json %>;
    #   </script>
    # 
    # WARNING: this helper only works with valid JSON. Using this on non-JSON values
    # will open up serious XSS vulnerabilities. For example, if you replace the
    # +current_user.to_json+ in the example above with user input instead, the browser
    # will happily eval() that string as JavaScript.
    # 
    # The escaping performed in this method is identical to those performed in the
    # ActiveSupport JSON encoder when +ActiveSupport.escape_html_entities_in_json+ is
    # set to true. Because this transformation is idempotent, this helper can be
    # applied even if +ActiveSupport.escape_html_entities_in_json+ is already true.
    # 
    # Therefore, when you are unsure if +ActiveSupport.escape_html_entities_in_json+
    # is enabled, or if you are unsure where your JSON string originated from, it
    # is recommended that you always apply this helper (other libraries, such as the
    # JSON gem, does not provide this kind of protection by default; also some gems
    # might override +#to_json+ to bypass ActiveSupport's encoder).
    # 
    # The output of this helper method is marked as HTML safe so that you can directly
    # include it inside a +<script>+ tag as shown above.
    # 
    # However, it is NOT safe to use the output of this inside an HTML attribute,
    # because quotation marks are not escaped. Doing so might break your page's layout.
    # If you intend to use this inside an HTML attribute, you should use the 
    # +html_escape+ helper (or its +h+ alias) instead:
    # 
    #   <div data-user-info="<%= h current_user.to_json %>">...</div>
    # 
    def json_escape(s)
      result = s.to_s.gsub(JSON_ESCAPE_REGEXP, JSON_ESCAPE)
      s.html_safe? ? result.html_safe : result
    end

    module_function :json_escape
  end
end

class Object
  def html_safe?
    false
  end
end

class Numeric
  def html_safe?
    true
  end
end

module ActiveSupport #:nodoc:
  class SafeBuffer < String
    UNSAFE_STRING_METHODS = %w(
      capitalize chomp chop delete downcase gsub lstrip next reverse rstrip
      slice squeeze strip sub succ swapcase tr tr_s upcase prepend
    )

    alias_method :original_concat, :concat
    private :original_concat

    class SafeConcatError < StandardError
      def initialize
        super 'Could not concatenate to the buffer because it is not html safe.'
      end
    end

    def [](*args)
      if args.size < 2
        super
      else
        if html_safe?
          new_safe_buffer = super
          new_safe_buffer.instance_eval { @html_safe = true }
          new_safe_buffer
        else
          to_str[*args]
        end
      end
    end

    def safe_concat(value)
      raise SafeConcatError unless html_safe?
      original_concat(value)
    end

    def initialize(*)
      @html_safe = true
      super
    end

    def initialize_copy(other)
      super
      @html_safe = other.html_safe?
    end

    def clone_empty
      self[0, 0]
    end

    def concat(value)
      if !html_safe? || value.html_safe?
        super(value)
      else
        super(ERB::Util.h(value))
      end
    end
    alias << concat

    def +(other)
      dup.concat(other)
    end

    def %(args)
      args = Array(args).map do |arg|
        if !html_safe? || arg.html_safe?
          arg
        else
          ERB::Util.h(arg)
        end
      end

      self.class.new(super(args))
    end

    def html_safe?
      defined?(@html_safe) && @html_safe
    end

    def to_s
      self
    end

    def to_param
      to_str
    end

    def encode_with(coder)
      coder.represent_scalar nil, to_str
    end

    UNSAFE_STRING_METHODS.each do |unsafe_method|
      if unsafe_method.respond_to?(unsafe_method)
        class_eval <<-EOT, __FILE__, __LINE__ + 1
          def #{unsafe_method}(*args, &block)       # def capitalize(*args, &block)
            to_str.#{unsafe_method}(*args, &block)  #   to_str.capitalize(*args, &block)
          end                                       # end

          def #{unsafe_method}!(*args)              # def capitalize!(*args)
            @html_safe = false                      #   @html_safe = false
            super                                   #   super
          end                                       # end
        EOT
      end
    end
  end
end

class String
  def html_safe
    ActiveSupport::SafeBuffer.new(self)
  end
end
