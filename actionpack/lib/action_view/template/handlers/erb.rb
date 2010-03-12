require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/string/output_safety'
require 'erubis'

module ActionView
  class OutputBuffer < ActiveSupport::SafeBuffer
    def <<(value)
      super(value.to_s)
    end
    alias :append= :<<
  end

  module Template::Handlers
    class Erubis < ::Erubis::Eruby
      def add_preamble(src)
        src << "@output_buffer = ActionView::OutputBuffer.new;"
      end

      def add_text(src, text)
        return if text.empty?
        src << "@output_buffer.safe_concat('" << escape_text(text) << "');"
      end

      def add_expr_literal(src, code)
        if code =~ /(do|\{)(\s*\|[^|]*\|)?\s*\Z/
          src << '@output_buffer.append= ' << code
        else
          src << '@output_buffer.append= (' << code << ');'
        end
      end

      def add_expr_escaped(src, code)
        src << '@output_buffer.append= ' << escaped_expr(code) << ';'
      end

      def add_postamble(src)
        src << '@output_buffer.to_s'
      end
    end

    class ERB < Template::Handler
      include Compilable

      ##
      # :singleton-method:
      # Specify trim mode for the ERB compiler. Defaults to '-'.
      # See ERb documentation for suitable values.
      cattr_accessor :erb_trim_mode
      self.erb_trim_mode = '-'

      self.default_format = Mime::HTML

      cattr_accessor :erb_implementation
      self.erb_implementation = Erubis

      def compile(template)
        source = template.source.gsub(/\A(<%(#.*coding[:=]\s*(\S+)\s*)-?%>)\s*\n?/, '')
        erb = "<% __in_erb_template=true %>#{source}"
        result = self.class.erb_implementation.new(erb, :trim=>(self.class.erb_trim_mode == "-")).src
        result = "#{$2}\n#{result}" if $2
        result
      end
    end
  end
end
