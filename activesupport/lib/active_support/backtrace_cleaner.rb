module ActiveSupport
  # Many backtraces include too much information that's not relevant for the context. This makes it hard to find the signal
  # in the backtrace and adds debugging time. With a BacktraceCleaner, you can setup filters and silencers for your particular
  # context, so only the relevant lines are included.
  #
  # If you need to reconfigure an existing BacktraceCleaner, like the one in Rails, to show as much as possible, you can always
  # call BacktraceCleaner#remove_silencers! Also, if you need to reconfigure an existing BacktraceCleaner so that it does not
  # filter or modify the paths of any lines of the backtrace, you can call BacktraceCleaner#remove_filters! These two methods
  # will give you a completely untouched backtrace.
  #
  # Example:
  #
  #   bc = BacktraceCleaner.new
  #   bc.add_filter   { |line| line.gsub(Rails.root, '') }
  #   bc.add_silencer { |line| line =~ /mongrel|rubygems/ }
  #   bc.clean(exception.backtrace) # will strip the Rails.root prefix and skip any lines from mongrel or rubygems
  #
  # Inspired by the Quiet Backtrace gem by Thoughtbot.
  class BacktraceCleaner
    def initialize
      @filters, @silencers = [], []
    end

    # Returns the backtrace after all filters and silencers has been run against it. Filters run first, then silencers.
    def clean(backtrace, kind = :silent)
      filtered = filter(backtrace)

      case kind
      when :silent
        silence(filtered)
      when :noise
        noise(filtered)
      else
        filtered
      end
    end

    # Adds a filter from the block provided. Each line in the backtrace will be mapped against this filter.
    #
    # Example:
    #
    #   # Will turn "/my/rails/root/app/models/person.rb" into "/app/models/person.rb"
    #   backtrace_cleaner.add_filter { |line| line.gsub(Rails.root, '') }
    def add_filter(&block)
      @filters << block
    end

    # Adds a silencer from the block provided. If the silencer returns true for a given line, it'll be excluded from the
    # clean backtrace.
    #
    # Example:
    #
    #   # Will reject all lines that include the word "mongrel", like "/gems/mongrel/server.rb" or "/app/my_mongrel_server/rb"
    #   backtrace_cleaner.add_silencer { |line| line =~ /mongrel/ }
    def add_silencer(&block)
      @silencers << block
    end

    # Will remove all silencers, but leave in the filters. This is useful if your context of debugging suddenly expands as
    # you suspect a bug in the libraries you use.
    def remove_silencers!
      @silencers = []
    end

    def remove_filters!
      @filters = []
    end

    private
      def filter(backtrace)
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
        @silencers.each do |s|
          backtrace = backtrace.select { |line| s.call(line) }
        end

        backtrace
      end
  end
end
