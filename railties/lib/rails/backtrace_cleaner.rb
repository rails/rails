require 'active_support/backtrace_cleaner'

module Rails
  class BacktraceCleaner < ActiveSupport::BacktraceCleaner
    ERB_METHOD_SIG = /:in `_run_erb_.*/
    APP_DIRS = %w( app config lib test )

    def initialize
      super
      add_filter   { |line| line.sub("#{Rails.root}/", '') }
      add_filter   { |line| line.sub(ERB_METHOD_SIG, '') }
      add_filter   { |line| line.sub('./', '/') } # for tests

      add_gem_filters

      add_silencer { |line| !APP_DIRS.any? { |dir| line =~ /^#{dir}/ } }
    end

    private
      def add_gem_filters
        return unless defined? Gem
        (Gem.path + [Gem.default_dir]).uniq.each do |path|
          # http://gist.github.com/30430
          add_filter { |line|
            line.sub(%r{(#{path})/gems/([^/]+)-([0-9.]+)/(.*)}, '\2 (\3) \4')
          }
        end
      end
  end

  # For installing the BacktraceCleaner in the test/unit
  module BacktraceFilterForTestUnit #:nodoc:
    def self.included(klass)
      klass.send :alias_method_chain, :filter_backtrace, :cleaning
    end

    def filter_backtrace_with_cleaning(backtrace, prefix=nil)
      backtrace = filter_backtrace_without_cleaning(backtrace, prefix)
      backtrace = backtrace.first.split("\n") if backtrace.size == 1
      Rails.backtrace_cleaner.clean(backtrace)
    end
  end
end
