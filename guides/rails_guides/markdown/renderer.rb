module RailsGuides
  class Markdown
    class Renderer < Redcarpet::Render::HTML
      def initialize(options={})
        super
      end

      def header(text, header_level)
        # Always increase the heading level by, so we can use h1, h2 heading in the document
        header_level += 1

        %(<h#{header_level} id="#{dom_id(text)}">#{text}</h#{header_level}>)
      end

      def preprocess(full_document)
        convert_notes(full_document)
      end

      private

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
            %Q(<div class="#{css_class}"><p>#{$2.strip}</p></div>\n)
          end
        end

        def dom_id(text)
          text.downcase.gsub(/[^a-z0-9]+/, '-').strip
        end
    end
  end
end
