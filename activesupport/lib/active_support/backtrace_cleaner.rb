# frozen_string_literal: true

module ActiveSupport
  # = Backtrace Cleaner
  #
  # BacktraceCleaner holds filters and silencers which will inspect and mutate line-by-line the application's backtrace.
  #
  # \Rails applications are configured by default to silence the backtraces of gems and standard libraries.
  # To obtain the verbose, unsuppressed backtrace, set the environment variable <tt>BACKTRACE=1</tt>.
  #
  #   BACKTRACE=1 ./bin/rails server
  #
  # In case more control is needed, use #add_filter, #add_silencer, and #clean to satisfy the requirements.
  #
  #   bc = ActiveSupport::BacktraceCleaner.new
  #   root = "#{Rails.root}/"
  #   bc.add_filter   { |line| line.start_with?(root) ? line.from(root.size) : line } # strip the Rails.root prefix
  #   bc.add_silencer { |line| /puma|rubygems/.match?(line) } # skip any lines from puma or rubygems
  #   bc.clean(exception.backtrace) # perform the cleanup
  #
  # Inspired by the Quiet Backtrace gem by thoughtbot.
  class BacktraceCleaner
    def initialize
      @filters, @silencers = [], []
      add_gem_filter
      add_gem_silencer
      add_stdlib_silencer
    end

    # Returns the backtrace after all filters and silencers have been run
    # against it. Filters run first, then silencers.
    def clean(backtrace, kind = :silent)
      filtered = filter_backtrace(backtrace)

      case kind
      when :silent
        silence(filtered)
      when :noise
        noise(filtered)
      else
        filtered
      end
    end
    alias :filter :clean

    # Returns the frame with all filters applied.
    # returns +nil+ if the frame was silenced.
    def clean_frame(frame, kind = :silent)
      frame = frame.to_s
      @filters.each do |f|
        frame = f.call(frame.to_s)
      end

      case kind
      when :silent
        frame unless @silencers.any? { |s| s.call(frame) }
      when :noise
        frame if @silencers.any? { |s| s.call(frame) }
      else
        frame
      end
    end

    # Adds a filter from the block provided. Each line in the backtrace will be
    # mapped against this filter.
    #
    #   # Will turn "/my/rails/root/app/models/person.rb" into "app/models/person.rb"
    #   root = "#{Rails.root}/"
    #   backtrace_cleaner.add_filter { |line| line.start_with?(root) ? line.from(root.size) : line }
    def add_filter(&block)
      @filters << block
    end

    # Adds a silencer from the block provided. If the silencer returns +true+
    # for a given line, it will be excluded from the clean backtrace.
    #
    #   # Will reject all lines that include the word "puma", like "/gems/puma/server.rb" or "/app/my_puma_server/rb"
    #   backtrace_cleaner.add_silencer { |line| /puma/.match?(line) }
    def add_silencer(&block)
      @silencers << block
    end

    # Removes all silencers, but leaves in the filters. Useful if your
    # context of debugging suddenly expands as you suspect a bug in one of
    # the libraries you use.
    def remove_silencers!
      @silencers = []
    end

    # Removes all filters, but leaves in the silencers. Useful if you suddenly
    # need to see entire filepaths in the backtrace that you had already
    # filtered out.
    def remove_filters!
      @filters = []
    end

    private
      FORMATTED_GEMS_PATTERN = /\A[^\/]+ \([\w.]+\) /

      def add_gem_filter
        gems_paths = (Gem.path | [Gem.default_dir]).map { |p| Regexp.escape(p) }
        return if gems_paths.empty?

        gems_regexp = %r{\A(#{gems_paths.join('|')})/(bundler/)?gems/([^/]+)-([\w.]+)/(.*)}
        gems_result = '\3 (\4) \5'
        add_filter { |line| line.sub(gems_regexp, gems_result) }
      end

      def add_gem_silencer
        add_silencer { |line| FORMATTED_GEMS_PATTERN.match?(line) }
      end

      def add_stdlib_silencer
        add_silencer { |line| line.start_with?(RbConfig::CONFIG["rubylibdir"]) }
      end

      def filter_backtrace(backtrace)
        @filters.each do |f|
          backtrace = backtrace.map { |line| f.call(line.to_s) }
        end

        backtrace
      end

      def silence(backtrace)
        @silencers.each do |s|
          backtrace = backtrace.reject { |line| s.call(line.to_s) }
        end

        backtrace
      end

      def noise(backtrace)
        backtrace.select do |line|
          @silencers.any? do |s|
            s.call(line.to_s)
          end
        end
      end
  end
end
