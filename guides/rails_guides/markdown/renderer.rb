module RailsGuides
  class Markdown
    class Renderer < Redcarpet::Render::HTML
      def initialize(options={})
        super
      end

      def block_code(code, language)
        <<-HTML
<div class="code_container">
<pre class="brush: #{brush_for(language)}; gutter: false; toolbar: false">
#{ERB::Util.h(code).strip}
</pre>
</div>
HTML
      end

      def header(text, header_level)
        # Always increase the heading level by, so we can use h1, h2 heading in the document
        header_level += 1

        %(<h#{header_level}>#{text}</h#{header_level}>)
      end

      def paragraph(text)
        if text =~ /^(TIP|IMPORTANT|CAUTION|WARNING|NOTE|INFO|TODO)[.:](.*?)/
          convert_notes(text)
        else
          "<p>#{text}</p>"
        end
      end

      private

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

        def convert_notes(body)
          # The following regexp detects special labels followed by a
          # paragraph, perhaps at the end of the document.
          #
          # It is important that we do not eat more than one newline
          # because formatting may be wrong otherwise. For example,
          # if a bulleted list follows the first item is not rendered
          # as a list item, but as a paragraph starting with a plain
          # asterisk.
          body.gsub(/^(TIP|IMPORTANT|CAUTION|WARNING|NOTE|INFO|TODO)[.:](.*?)(\n(?=\n)|\Z)/m) do |m|
            css_class = case $1
                        when 'CAUTION', 'IMPORTANT'
                          'warning'
                        when 'TIP'
                          'info'
                        else
                          $1.downcase
                        end
            %(<div class="#{css_class}"><p>#{$2.strip}</p></div>)
          end
        end
    end
  end
end
