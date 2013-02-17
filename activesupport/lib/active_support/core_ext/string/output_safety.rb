require 'erb'

class ERB
  module Util
    HTML_ESCAPE = { '&' => '&amp;',  '>' => '&gt;',   '<' => '&lt;', '"' => '&quot;', "'" => '&#39;' }
    JSON_ESCAPE = { '&' => '\u0026', '>' => '\u003E', '<' => '\u003C' }
    HTML_ESCAPE_ONCE_REGEXP = /["><']|&(?!([a-zA-Z]+|(#\d+));)/
    JSON_ESCAPE_REGEXP = /[&"><]/

    # A utility method for escaping HTML tag characters.
    # This method is also aliased as <tt>h</tt>.
    #
    # In your ERb templates, use this method to escape any unsafe content. For example:
    #   <%=h @person.name %>
    #
    # ==== Example:
    #   puts html_escape("is a > 0 & a < 10?")
    #   # => is a &gt; 0 &amp; a &lt; 10?
    if RUBY_VERSION > '1.9'
      def html_escape(s)
        s = s.to_s
        if s.html_safe?
          s
        else
          s.gsub(/[&"'><]/, HTML_ESCAPE).html_safe
        end
      end
    else
      def html_escape(s)
        s = s.to_s
        if s.html_safe?
          s
        else
          s.gsub(/[&"'><]/){ |x| HTML_ESCAPE[x] }.html_safe
        end
      end
    end

    undef :h
    alias h html_escape

    module_function :html_escape
    module_function :h

    # A utility method for escaping HTML without affecting existing escaped entities.
    #
    #   html_escape_once('1 < 2 &amp; 3')
    #   # => "1 &lt; 2 &amp; 3"
    #
    #   html_escape_once('&lt;&lt; Accept & Checkout')
    #   # => "&lt;&lt; Accept &amp; Checkout"
    if RUBY_VERSION > '1.9'
      def html_escape_once(s)
        result = s.to_s.gsub(HTML_ESCAPE_ONCE_REGEXP, HTML_ESCAPE)
        s.html_safe? ? result.html_safe : result
      end
    else
      def html_escape_once(s)
        result = s.to_s.gsub(HTML_ESCAPE_ONCE_REGEXP) { |special| HTML_ESCAPE[special] }
        s.html_safe? ? result.html_safe : result
      end
    end

    module_function :html_escape_once

    # A utility method for escaping HTML entities in JSON strings
    # using \uXXXX JavaScript escape sequences for string literals:
    #
    #   json_escape('is a > 0 & a < 10?')
    #   # => is a \u003E 0 \u0026 a \u003C 10?
    #
    # Note that after this operation is performed the output is not
    # valid JSON. In particular double quotes are removed:
    #
    #   json_escape('{"name":"john","created_at":"2010-04-28T01:39:31Z","id":1}')
    #   # => {name:john,created_at:2010-04-28T01:39:31Z,id:1}
    if RUBY_VERSION > '1.9'
      def json_escape(s)
        result = s.to_s.gsub(JSON_ESCAPE_REGEXP, JSON_ESCAPE)
        s.html_safe? ? result.html_safe : result
      end
    else
      def json_escape(s)
        result = s.to_s.gsub(JSON_ESCAPE_REGEXP) { |special| JSON_ESCAPE[special] }
        s.html_safe? ? result.html_safe : result
      end
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
    def +(other)
      dup.concat(other)
    end

    def html_safe?
      true
    end

    def html_safe
      self
    end

    def to_s
      self
    end

    def to_yaml(*args)
      to_str.to_yaml(*args)
    end
  end
end

class String
  alias safe_concat concat

  def as_str
    self
  end

  def html_safe
    ActiveSupport::SafeBuffer.new(self)
  end

  def html_safe?
    false
  end
end
