require 'active_support/core_ext/object/blank'
require 'active_support/ordered_hash'

module RailsGuides
  class Indexer
    attr_reader :body, :result, :warnings, :level_hash

    def initialize(body, warnings)
      @body     = body
      @result   = @body.dup
      @warnings = warnings
    end

    def index
      @level_hash = process(body)
    end

    private

    def process(string, current_level=3, counters=[1])
      s = StringScanner.new(string)

      level_hash = ActiveSupport::OrderedHash.new

      while !s.eos?
        re = %r{^h(\d)(?:\((#.*?)\))?\s*\.\s*(.*)$}
        s.match?(re)
        if matched = s.matched
          matched =~ re
          level, idx, title = $1.to_i, $2, $3.strip

          if level < current_level
            # This is needed. Go figure.
            return level_hash
          elsif level == current_level
            index = counters.join(".")
            idx ||= '#' + title_to_idx(title)

            raise "Parsing Fail" unless @result.sub!(matched, "h#{level}(#{idx}). #{index} #{title}")

            key = {
              :title => title,
              :id => idx
            }
            # Recurse
            counters << 1
            level_hash[key] = process(s.post_match, current_level + 1, counters)
            counters.pop

            # Increment the current level
            last = counters.pop
            counters << last + 1
          end
        end
        s.getch
      end
      level_hash
    end

    def title_to_idx(title)
      idx = title.strip.downcase.gsub(/\s+|_/, '-').delete('^a-z0-9-').sub(/^[^a-z]*/, '')
      if warnings && idx.blank?
        puts "BLANK ID: please put an explicit ID for section #{title}, as in h5(#my-id)"
      end
      idx
    end
  end
end
