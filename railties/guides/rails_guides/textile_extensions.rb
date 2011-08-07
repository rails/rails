require 'active_support/core_ext/object/inclusion'

module RailsGuides
  module TextileExtensions
    def notestuff(body)
      # The following regexp detects special labels followed by a
      # paragraph, perhaps at the end of the document.
      #
      # It is important that we do not eat more than one newline
      # because formatting may be wrong otherwise. For example,
      # if a bulleted list follows the first item is not rendered
      # as a list item, but as a paragraph starting with a plain
      # asterisk.
      body.gsub!(/^(TIP|IMPORTANT|CAUTION|WARNING|NOTE|INFO)[.:](.*?)(\n(?=\n)|\Z)/m) do |m|
        css_class = case $1
                    when 'CAUTION', 'IMPORTANT'
                      'warning'
                    when 'TIP'
                      'info'
                    else
                      $1.downcase
                    end
        %Q(<div class="#{css_class}"><p>#{$2.strip}</p></div>)
      end
    end

    def plusplus(body)
      body.gsub!(/\+(.*?)\+/) do |m|
        "<notextile><tt>#{$1}</tt></notextile>"
      end

      # The real plus sign
      body.gsub!('<plus>', '+')
    end

    def brush_for(code_type)
      case code_type
        when 'ruby', 'sql', 'plain'
          code_type
        when 'erb'
          'ruby; html-script: true'
        when 'html'
          'xml' # html is understood, but there are .xml rules in the CSS
        else
          'plain'
      end
    end

    def code(body)
      body.gsub!(%r{<(yaml|shell|ruby|erb|html|sql|plain)>(.*?)</\1>}m) do |m|
        <<HTML
<notextile>
<div class="code_container">
<pre class="brush: #{brush_for($1)}; gutter: false; toolbar: false">
#{ERB::Util.h($2).strip}
</pre>
</div>
</notextile>
HTML
      end
    end
  end
end
