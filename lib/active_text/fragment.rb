module ActiveText
  class Fragment
    class << self
      def wrap(fragment_or_html)
        case fragment_or_html
        when self
          fragment_or_html
        when Nokogiri::HTML::DocumentFragment
          new(fragment_or_html)
        else
          from_html(fragment_or_html)
        end
      end

      def from_html(html)
        new(ActiveText::HtmlConversion.fragment_for_html(html.to_s.strip))
      end
    end

    attr_reader :source

    def initialize(source)
      @source = source
    end

    def find_all(selector)
      source.css(selector)
    end

    def update
      yield source = self.source.clone
      self.class.new(source)
    end

    def replace(selector)
      update do |source|
        source.css(selector).each do |node|
          node.replace(yield(node).to_s)
        end
      end
    end

    def to_plain_text
      @plain_text ||= PlainTextConversion.node_to_plain_text(source)
    end

    def to_html
      @html ||= HtmlConversion.node_to_html(source)
    end

    def to_s
      to_html
    end
  end
end
