require 'erb'

class ERB
  module Util
    HTML_ESCAPE = { '&' => '&amp;', '"' => '&quot;', '>' => '&gt;', '<' => '&lt;' }

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
  end
end

module ActionView
  module TemplateHandlers
    class ERB < TemplateHandler
      include Compilable

      def compile(template)
        ::ERB.new(template, nil, @view.erb_trim_mode).src
      end

      def cache_fragment(block, name = {}, options = nil) #:nodoc:
        @view.fragment_for(block, name, options) do
          eval(ActionView::Base.erb_variable, block.binding)
        end
      end
    end
  end
end
