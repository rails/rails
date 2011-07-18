require 'active_support/core_ext/object/inclusion'

module RailsGuides
  module TextileExtensions
    def notestuff(body)
      body.gsub!(/^(IMPORTANT|CAUTION|WARNING|NOTE|INFO)[.:](.*)$/) do |m|
        css_class = $1.downcase
        css_class = 'warning' if css_class.in?(['caution', 'important'])

        result = "<div class='#{css_class}'><p>"
        result << $2.strip
        result << '</p></div>'
        result
      end
    end

    def tip(body)
      body.gsub!(/^TIP[.:](.*)$/) do |m|
        result = "<div class='info'><p>"
        result << $1.strip
        result << '</p></div>'
        result
      end
    end

    def plusplus(body)
      body.gsub!(/\+(.*?)\+/) do |m|
        "&lt;notextile&gt;<tt>#{$1}</tt>&lt;/notextile&gt;"
      end

      # The real plus sign
      body.gsub!('<plus>', '+')
    end

    def code(body)
      body.gsub!(%r{<(yaml|shell|ruby|erb|html|sql|plain)>(.*?)</\1>}m) do |m|
        es = ERB::Util.h($2)
        css_class = $1.in?(['erb', 'shell']) ? 'html' : $1
        %{&lt;notextile&gt;<div class="code_container"><code class="#{css_class}">#{es}</code></div>&lt;/notextile&gt;}
      end
    end
  end
end

