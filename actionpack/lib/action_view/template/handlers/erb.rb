require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/string/output_safety'
require 'erubis'

module ActionView
  module TemplateHandlers
    class Erubis < ::Erubis::Eruby
      def add_preamble(src)
        src << "@output_buffer = ActionView::SafeBuffer.new;"
      end

      def add_text(src, text)
        src << "@output_buffer << ('" << escape_text(text) << "'.html_safe!);"
      end

      def add_expr_literal(src, code)
        src << '@output_buffer << ((' << code << ').to_s);'
      end

      def add_expr_escaped(src, code)
        src << '@output_buffer << ' << escaped_expr(code) << ';'
      end

      def add_postamble(src)
        src << '@output_buffer.to_s'
      end
    end

    class ERB < TemplateHandler
      include Compilable

      ##
      # :singleton-method:
      # Specify trim mode for the ERB compiler. Defaults to '-'.
      # See ERb documentation for suitable values.
      cattr_accessor :erb_trim_mode
      self.erb_trim_mode = '-'

      self.default_format = Mime::HTML
      
      cattr_accessor :erubis_implementation
      self.erubis_implementation = Erubis

      def compile(template)
        source = template.source.gsub(/\A(<%(#.*coding[:=]\s*(\S+)\s*)-?%>)\s*\n?/, '')
        erb = "<% __in_erb_template=true %>#{source}"
        result = self.class.erubis_implementation.new(erb, :trim=>(self.class.erb_trim_mode == "-")).src
        result = "#{$2}\n#{result}" if $2
        result
      end
    end
  end
end
