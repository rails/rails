# frozen_string_literal: true

module Rails
  module Command
    module Spellchecker # :nodoc:
      class << self
        def suggest(word, from:)
          if defined?(DidYouMean::SpellChecker)
            DidYouMean::SpellChecker.new(dictionary: from.map(&:to_s)).correct(word).first
          else
            from.sort_by { |w| levenshtein_distance(word, w) }.first
          end
        end

        private
          # This code is based directly on the Text gem implementation.
          # Copyright (c) 2006-2013 Paul Battley, Michael Neumann, Tim Fletcher.
          #
          # Returns a value representing the "cost" of transforming str1 into str2.
          def levenshtein_distance(str1, str2) # :doc:
            s = str1
            t = str2
            n = s.length
            m = t.length

            return m if 0 == n
            return n if 0 == m

            d = (0..m).to_a
            x = nil

            # avoid duplicating an enumerable object in the loop
            str2_codepoint_enumerable = str2.each_codepoint

            str1.each_codepoint.with_index do |char1, i|
              e = i + 1

              str2_codepoint_enumerable.with_index do |char2, j|
                cost = (char1 == char2) ? 0 : 1
                x = [
                  d[j + 1] + 1, # insertion
                  e + 1,        # deletion
                  d[j] + cost   # substitution
                ].min
                d[j] = e
                e = x
              end

              d[m] = x
            end

            x
          end
      end
    end
  end
end
