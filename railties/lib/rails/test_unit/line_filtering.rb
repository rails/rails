require "method_source"

module Rails
  module LineFiltering # :nodoc:
    def run(reporter, options = {})
      if options[:patterns] && options[:patterns].any? { |p| p =~ /:\d+/ }
        options[:filter] = \
          CompositeFilter.new(self, options[:filter], options[:patterns])
      end

      super
    end
  end

  class CompositeFilter # :nodoc:
    attr_reader :named_filter

    def initialize(runnable, filter, patterns)
      @runnable = runnable
      @named_filter = derive_named_filter(filter)
      @filters = [ @named_filter, *derive_line_filters(patterns) ].compact
    end

    # Minitest uses === to find matching filters.
    def ===(method)
      @filters.any? { |filter| filter === method }
    end

    private
      def derive_named_filter(filter)
        if filter.respond_to?(:named_filter)
          filter.named_filter
        elsif filter =~ %r%/(.*)/% # Regexp filtering copied from Minitest.
          Regexp.new $1
        elsif filter.is_a?(String)
          filter
        end
      end

      def derive_line_filters(patterns)
        patterns.flat_map do |file_and_line|
          file, *lines = file_and_line.split(":")

          if lines.empty?
            Filter.new(@runnable, file, nil) if file
          else
            lines.map { |line| Filter.new(@runnable, file, line) }
          end
        end
      end
  end

  class Filter # :nodoc:
    def initialize(runnable, file, line)
      @runnable, @file = runnable, File.expand_path(file)
      @line = line.to_i if line
    end

    def ===(method)
      return unless @runnable.method_defined?(method)

      if @line
        test_file, test_range = definition_for(@runnable.instance_method(method))
        test_file == @file && test_range.include?(@line)
      else
        @runnable.instance_method(method).source_location.first == @file
      end
    end

    private
      def definition_for(method)
        file, start_line = method.source_location
        end_line = method.source.count("\n") + start_line - 1

        return file, start_line..end_line
      end
  end
end
