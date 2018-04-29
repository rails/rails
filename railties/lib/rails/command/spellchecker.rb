# frozen_string_literal: true

module Rails
  module Command
    module Spellchecker # :nodoc:
      def self.suggest(word, from:)
        return "" unless defined?(::DidYouMean::SpellChecker)
        DidYouMean::SpellChecker.new(dictionary: from.map(&:to_s)).correct(word).first
      end
    end
  end
end
