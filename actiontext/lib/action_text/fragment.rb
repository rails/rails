# frozen_string_literal: true

module ActionText
  class Fragment
    class << self
      def wrap(fragment_or_html)
        case fragment_or_html
        when self
          fragment_or_html
        else
          if ActionText::Document.is_fragment?(fragment_or_html)
            new(fragment_or_html)
          else
            from_html(fragment_or_html)
          end
        end
      end

      def from_html(html)
        new(ActionText::Document.fragment_for_html(html.to_s.strip))
      end
    end

    attr_reader :source

    def initialize(source)
      @source = source
    end

    def find_all(selector)
      ActionText::Document.find(source, selector)
    end

    def update
      yield source = ActionText::Document.clone_node(self.source)
      self.class.new(source)
    end

    def replace(selector)
      update do |source|
        ActionText::Document.find(source, selector).each do |node|
          ActionText::Document.replace_node(node, yield(node))
        end
      end
    end

    def to_plain_text
      @plain_text ||= ActionText::Document.node_to_text(source)
    end

    def to_html
      @html ||= ActionText::Document.node_to_html(source)
    end

    def to_s
      to_html
    end
  end
end
