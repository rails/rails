module Rails
  class BacktraceCleaner < ActiveSupport::BacktraceCleaner
    ERB_METHOD_SIG = /:in `_run_erb_.*/

    VENDOR_DIRS  = %w( vendor/plugins vendor/gems vendor/rails )
    MONGREL_DIRS = %w( lib/mongrel bin/mongrel )
    RAILS_NOISE  = %w( script/server )
    RUBY_NOISE   = %w( rubygems/custom_require benchmark.rb )

    ALL_NOISE    = VENDOR_DIRS + MONGREL_DIRS + RAILS_NOISE + RUBY_NOISE

    def initialize
      super
      add_filter   { |line| line.sub(RAILS_ROOT, '') }
      add_filter   { |line| line.sub(ERB_METHOD_SIG, '') }
      add_filter   { |line| line.sub('./', '/') } # for tests
      add_silencer { |line| ALL_NOISE.any? { |dir| line.include?(dir) } }
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