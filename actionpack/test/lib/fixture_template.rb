module ActionView #:nodoc:
  class FixtureResolver < PathResolver
    def initialize(hash = {}, options = {})
      super(options)
      @hash = hash
    end

  private

    def query(path, exts)
      query = Regexp.escape(path)
      exts.each do |ext|
        query << '(?:' << ext.map {|e| e && Regexp.escape(".#{e}") }.join('|') << ')'
      end

      templates = []
      @hash.select { |k,v| k =~ /^#{query}$/ }.each do |path, source|
        templates << Template.new(source, path, *path_to_details(path))
      end
      templates.sort_by {|t| -t.details.values.compact.size }
    end

  end
end