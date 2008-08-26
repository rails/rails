require 'erb'

class ERB
  module Util
    HTML_ESCAPE = { '&' => '&amp;',  '>' => '&gt;',   '<' => '&lt;', '"' => '&quot;' }
    JSON_ESCAPE = { '&' => '\u0026', '>' => '\u003E', '<' => '\u003C' }

    # A utility method for escaping HTML tag characters.
    # This method is also aliased as <tt>h</tt>.
    #
    # In your ERb templates, use this method to escape any unsafe content. For example:
    #   <%=h @person.name %>
    #
    # ==== Example:
    #   puts html_escape("is a > 0 & a < 10?")
    #   # => is a &gt; 0 &amp; a &lt; 10?
    def html_escape(s)
      s.to_s.gsub(/[&"><]/) { |special| HTML_ESCAPE[special] }
    end

    # A utility method for escaping HTML entities in JSON strings.
    # This method is also aliased as <tt>j</tt>.
    #
    # In your ERb templates, use this method to escape any HTML entities:
    #   <%=j @person.to_json %>
    #
    # ==== Example:
    #   puts json_escape("is a > 0 & a < 10?")
    #   # => is a \u003E 0 \u0026 a \u003C 10?
    def json_escape(s)
      s.to_s.gsub(/[&"><]/) { |special| JSON_ESCAPE[special] }
    end

    alias j json_escape
    module_function :j
    module_function :json_escape
  end
end

module ActionView
  module TemplateHandlers
    class ERB < TemplateHandler
      include Compilable

      # Specify trim mode for the ERB compiler. Defaults to '-'.
      # See ERb documentation for suitable values.
      cattr_accessor :erb_trim_mode
      self.erb_trim_mode = '-'

      def compile(template)
        src = ::ERB.new("<% __in_erb_template=true %>#{template.source}", nil, erb_trim_mode, '@output_buffer').src

        # Ruby 1.9 prepends an encoding to the source. However this is
        # useless because you can only set an encoding on the first line
        RUBY_VERSION >= '1.9' ? src.sub(/\A#coding:.*\n/, '') : src
      end
    end
  end
end
