require 'action_view/template/resolver'

module ActionView #:nodoc:
  # Use FixtureResolver in your tests to simulate the presence of files on the
  # file system. This is used internally by Rails' own test suite, and is
  # useful for testing extensions that have no way of knowing what the file
  # system will look like at runtime.
  class FixtureResolver < PathResolver
    attr_reader :hash

    def initialize(hash = {}, pattern=nil)
      super(pattern)
      @hash = hash
    end

    def to_s
      @hash.keys.join(', ')
    end

  private

    def query(path, exts, formats)
      query = ""
      EXTENSIONS.each do |ext|
        query << '(' << exts[ext].map {|e| e && Regexp.escape(".#{e}") }.join('|') << '|)'
      end
      query = /^(#{Regexp.escape(path)})#{query}$/

      templates = []
      @hash.each do |_path, array|
        source, updated_at = array
        next unless _path =~ query
        handler, format = extract_handler_and_format(_path, formats)
        templates << Template.new(source, _path, handler,
          virtual_path: path.virtual, format: format, updated_at: updated_at)
      end

      templates.sort_by {|t| -t.identifier.match(/^#{query}$/).captures.reject(&:blank?).size }
    end
  end

  class NullResolver < PathResolver
    def query(path, exts, formats)
      handler, format = extract_handler_and_format(path, formats)
      [ActionView::Template.new("Template generated by Null Resolver", path, handler, virtual_path: path, format: format)]
    end
  end

end

