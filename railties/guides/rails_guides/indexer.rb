module RailsGuides
  class Indexer
    attr_reader :body, :result, :level_hash

    def initialize(body)
      @body = body
      @result = @body.dup
    end

    def index
      @level_hash = process(body)
    end

    private

    def process(string, current_level= 3, counters = [1])
      s = StringScanner.new(string)

      level_hash = ActiveSupport::OrderedHash.new

      while !s.eos?
        s.match?(/\h[0-9]\..*$/)
        if matched = s.matched
          matched =~ /\h([0-9])\.(.*)$/
          level, title = $1.to_i, $2

          if level < current_level
            # This is needed. Go figure.
            return level_hash
          elsif level == current_level
            index = counters.join(".")
            bookmark = '#' + title.gsub(/[^a-z0-9\-_]+/i, '').underscore.dasherize

            raise "Parsing Fail" unless @result.sub!(matched, "h#{level}(#{bookmark}). #{index}#{title}")

            key = {
              :title => title,
              :id => bookmark
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
  end
end
