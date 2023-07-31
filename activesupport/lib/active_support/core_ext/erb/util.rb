# frozen_string_literal: true

require "erb"

module ActiveSupport
  module CoreExt
    module ERBUtil
      # HTML escapes strings but doesn't wrap them with an ActiveSupport::SafeBuffer.
      # This method is not for public consumption! Seriously!
      def html_escape(s) # :nodoc:
        s = s.to_s
        if s.html_safe?
          s
        else
          super(ActiveSupport::Multibyte::Unicode.tidy_bytes(s))
        end
      end
      alias :unwrapped_html_escape :html_escape # :nodoc:

      # A utility method for escaping HTML tag characters.
      # This method is also aliased as <tt>h</tt>.
      #
      #   puts html_escape('is a > 0 & a < 10?')
      #   # => is a &gt; 0 &amp; a &lt; 10?
      def html_escape(s) # rubocop:disable Lint/DuplicateMethods
        unwrapped_html_escape(s).html_safe
      end
      alias h html_escape
    end

    module ERBUtilPrivate
      include ERBUtil
      private :unwrapped_html_escape, :html_escape, :h
    end
  end
end

class ERB
  module Util
    HTML_ESCAPE = { "&" => "&amp;",  ">" => "&gt;",   "<" => "&lt;", '"' => "&quot;", "'" => "&#39;" }
    HTML_ESCAPE_ONCE_REGEXP = /["><']|&(?!([a-zA-Z]+|(#\d+)|(#[xX][\dA-Fa-f]+));)/

    # Following XML requirements: https://www.w3.org/TR/REC-xml/#NT-Name
    TAG_NAME_START_CODEPOINTS = "@:A-Z_a-z\u{C0}-\u{D6}\u{D8}-\u{F6}\u{F8}-\u{2FF}\u{370}-\u{37D}\u{37F}-\u{1FFF}" \
                                "\u{200C}-\u{200D}\u{2070}-\u{218F}\u{2C00}-\u{2FEF}\u{3001}-\u{D7FF}\u{F900}-\u{FDCF}" \
                                "\u{FDF0}-\u{FFFD}\u{10000}-\u{EFFFF}"
    INVALID_TAG_NAME_START_REGEXP = /[^#{TAG_NAME_START_CODEPOINTS}]/
    TAG_NAME_FOLLOWING_CODEPOINTS = "#{TAG_NAME_START_CODEPOINTS}\\-.0-9\u{B7}\u{0300}-\u{036F}\u{203F}-\u{2040}"
    INVALID_TAG_NAME_FOLLOWING_REGEXP = /[^#{TAG_NAME_FOLLOWING_CODEPOINTS}]/
    SAFE_XML_TAG_NAME_REGEXP = /\A[#{TAG_NAME_START_CODEPOINTS}][#{TAG_NAME_FOLLOWING_CODEPOINTS}]*\z/
    TAG_NAME_REPLACEMENT_CHAR = "_"

    prepend ActiveSupport::CoreExt::ERBUtilPrivate
    singleton_class.prepend ActiveSupport::CoreExt::ERBUtil

    # A utility method for escaping HTML without affecting existing escaped entities.
    #
    #   html_escape_once('1 < 2 &amp; 3')
    #   # => "1 &lt; 2 &amp; 3"
    #
    #   html_escape_once('&lt;&lt; Accept & Checkout')
    #   # => "&lt;&lt; Accept &amp; Checkout"
    def html_escape_once(s)
      ActiveSupport::Multibyte::Unicode.tidy_bytes(s.to_s).gsub(HTML_ESCAPE_ONCE_REGEXP, HTML_ESCAPE).html_safe
    end

    module_function :html_escape_once

    # A utility method for escaping HTML entities in JSON strings. Specifically, the
    # &, > and < characters are replaced with their equivalent unicode escaped form -
    # \u0026, \u003e, and \u003c. The Unicode sequences \u2028 and \u2029 are also
    # escaped as they are treated as newline characters in some JavaScript engines.
    # These sequences have identical meaning as the original characters inside the
    # context of a JSON string, so assuming the input is a valid and well-formed
    # JSON value, the output will have equivalent meaning when parsed:
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
    #   <script>
    #     var currentUser = <%= raw json_escape(current_user.to_json) %>;
    #   </script>
    #
    # It is necessary to +raw+ the result of +json_escape+, so that quotation marks
    # don't get converted to <tt>&quot;</tt> entities. +json_escape+ doesn't
    # automatically flag the result as HTML safe, since the raw value is unsafe to
    # use inside HTML attributes.
    #
    # If your JSON is being used downstream for insertion into the DOM, be aware of
    # whether or not it is being inserted via <tt>html()</tt>. Most jQuery plugins do this.
    # If that is the case, be sure to +html_escape+ or +sanitize+ any user-generated
    # content returned by your JSON.
    #
    # If you need to output JSON elsewhere in your HTML, you can just do something
    # like this, as any unsafe characters (including quotation marks) will be
    # automatically escaped for you:
    #
    #   <div data-user-info="<%= current_user.to_json %>">...</div>
    #
    # WARNING: this helper only works with valid JSON. Using this on non-JSON values
    # will open up serious XSS vulnerabilities. For example, if you replace the
    # +current_user.to_json+ in the example above with user input instead, the browser
    # will happily <tt>eval()</tt> that string as JavaScript.
    #
    # The escaping performed in this method is identical to those performed in the
    # Active Support JSON encoder when +ActiveSupport.escape_html_entities_in_json+ is
    # set to true. Because this transformation is idempotent, this helper can be
    # applied even if +ActiveSupport.escape_html_entities_in_json+ is already true.
    #
    # Therefore, when you are unsure if +ActiveSupport.escape_html_entities_in_json+
    # is enabled, or if you are unsure where your JSON string originated from, it
    # is recommended that you always apply this helper (other libraries, such as the
    # JSON gem, do not provide this kind of protection by default; also some gems
    # might override +to_json+ to bypass Active Support's encoder).
    def json_escape(s)
      result = s.to_s.dup
      result.gsub!(">", '\u003e')
      result.gsub!("<", '\u003c')
      result.gsub!("&", '\u0026')
      result.gsub!("\u2028", '\u2028')
      result.gsub!("\u2029", '\u2029')
      s.html_safe? ? result.html_safe : result
    end

    module_function :json_escape

    # A utility method for escaping XML names of tags and names of attributes.
    #
    #   xml_name_escape('1 < 2 & 3')
    #   # => "1___2___3"
    #
    # It follows the requirements of the specification: https://www.w3.org/TR/REC-xml/#NT-Name
    def xml_name_escape(name)
      name = name.to_s
      return "" if name.blank?
      return name if name.match?(SAFE_XML_TAG_NAME_REGEXP)

      starting_char = name[0]
      starting_char.gsub!(INVALID_TAG_NAME_START_REGEXP, TAG_NAME_REPLACEMENT_CHAR)

      return starting_char if name.size == 1

      following_chars = name[1..-1]
      following_chars.gsub!(INVALID_TAG_NAME_FOLLOWING_REGEXP, TAG_NAME_REPLACEMENT_CHAR)

      starting_char << following_chars
    end
    module_function :xml_name_escape

    # Tokenizes a line of ERB.  This is really just for error reporting and
    # nobody should use it.
    def self.tokenize(source) # :nodoc:
      require "strscan"
      source = StringScanner.new(source.chomp)
      tokens = []

      start_re = /<%(?:={1,2}|-|\#|%)?/m
      finish_re = /(?:[-=])?%>/m

      while !source.eos?
        pos = source.pos
        source.scan_until(/(?:#{start_re}|#{finish_re})/)
        raise NotImplementedError if source.matched.nil?
        len = source.pos - source.matched.bytesize - pos

        case source.matched
        when start_re
          tokens << [:TEXT, source.string[pos, len]] if len > 0
          tokens << [:OPEN, source.matched]
          if source.scan(/(.*?)(?=#{finish_re}|\z)/m)
            tokens << [:CODE, source.matched] unless source.matched.empty?
            tokens << [:CLOSE, source.scan(finish_re)] unless source.eos?
          else
            raise NotImplementedError
          end
        when finish_re
          tokens << [:CODE, source.string[pos, len]] if len > 0
          tokens << [:CLOSE, source.matched]
        else
          raise NotImplementedError, source.matched
        end
      end

      tokens
    end
  end
end
