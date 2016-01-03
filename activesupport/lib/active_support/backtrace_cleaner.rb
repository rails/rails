module ActiveSupport
  # Backtraces often include many lines that are not relevant for the context
  # under review. This makes it hard to find the signal amongst the backtrace
  # noise, and adds debugging time. With a BacktraceCleaner, filters and
  # silencers are used to remove the noisy lines, so that only the most relevant
  # lines remain.
  #
  # Filters are used to modify lines of data, while silencers are used to remove
  # lines entirely. The typical filter use case is to remove lengthy path
  # information from the start of each line, and view file paths relevant to the
  # app directory instead of the file system root. The typical silencer use case
  # is to exclude the output of a noisy library from the backtrace, so that you
  # can focus on the rest.
  #
  #   bc = BacktraceCleaner.new
  #   bc.add_filter   { |line| line.gsub(Rails.root.to_s, '') } # strip the Rails.root prefix
  #   bc.add_silencer { |line| line =~ /mongrel|rubygems/ } # skip any lines from mongrel or rubygems
  #   bc.clean(exception.backtrace) # perform the cleanup
  #
  # To reconfigure an existing BacktraceCleaner (like the default one in Rails)
  # and show as much data as possible, you can always call
  # <tt>BacktraceCleaner#remove_silencers!</tt>, which will restore the
  # backtrace to a pristine state. If you need to reconfigure an existing
  # BacktraceCleaner so that it does not filter or modify the paths of any lines
  # of the backtrace, you can call <tt>BacktraceCleaner#remove_filters!</tt>
  # These two methods will give you a completely untouched backtrace.
  #
  # Inspired by the Quiet Backtrace gem by thoughtbot.
  class BacktraceCleaner
    def initialize
      @filters, @silencers = [], []
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

    # Adds a filter from the block provided. Each line in the backtrace will be
    # mapped against this filter.
    #
    #   # Will turn "/my/rails/root/app/models/person.rb" into "/app/models/person.rb"
    #   backtrace_cleaner.add_filter { |line| line.gsub(Rails.root, '') }
    def add_filter(&block)
      @filters << block
    end

    # Adds a silencer from the block provided. If the silencer returns +true+
    # for a given line, it will be excluded from the clean backtrace.
    #
    #   # Will reject all lines that include the word "mongrel", like "/gems/mongrel/server.rb" or "/app/my_mongrel_server/rb"
    #   backtrace_cleaner.add_silencer { |line| line =~ /mongrel/ }
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
      def filter_backtrace(backtrace)
        @filters.each do |f|
          backtrace = backtrace.map { |line| f.call(line) }
        end

        backtrace
      end

      def silence(backtrace)
        @silencers.each do |s|
          backtrace = backtrace.reject { |line| s.call(line) }
        end

        backtrace
      end

      def noise(backtrace)
        backtrace - silence(backtrace)
      end
  end
end
