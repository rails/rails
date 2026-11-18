# frozen_string_literal: true

module ActionText
  module Serialization
    extend ActiveSupport::Concern

    class_methods do
      def load(content)
        new(content) if content
      end

      def dump(content)
        case content
        when nil
          nil
        when self
          content.to_html
        when ActionText::RichText
          content.body.to_html
        else
          new(content).to_html
        end
      end
    end

    # Marshal compatibility

    class_methods do
      alias_method :_load, :load
    end

    def _dump(*)
      self.class.dump(self)
    end
  end
end
