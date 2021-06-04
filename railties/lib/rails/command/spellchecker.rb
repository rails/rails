# frozen_string_literal: true

module Rails
  module Command
    module Spellchecker # :nodoc:
      class << self
        def suggest(word, from:)
          if defined?(DidYouMean::SpellChecker)
            DidYouMean::SpellChecker.new(dictionary: from.map(&:to_s)).correct(word).first
          end
        end
      end
    end
  end
end
