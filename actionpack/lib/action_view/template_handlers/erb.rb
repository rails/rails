require 'erb'

class ERB
  module Util
    HTML_ESCAPE = { '&' => '&amp;', '"' => '&quot;', '>' => '&gt;', '<' => '&lt;' }

    def html_escape(s)
      s.to_s.gsub(/[&"><]/) { |special| HTML_ESCAPE[special] }
    end
  end
end

module ActionView
  module TemplateHandlers
    class ERB < TemplateHandler
      def compile(template)
        ::ERB.new(template, nil, @view.erb_trim_mode).src
      end
    end
  end
end
