require 'active_support/backtrace_cleaner'

module Rails
  class BacktraceCleaner < ActiveSupport::BacktraceCleaner
    APP_DIRS_PATTERN = /^\/?(app|config|lib|test)/
    RENDER_TEMPLATE_PATTERN = /:in `_render_template_\w*'/

    def initialize
      super
      add_filter   { |line| line.sub("#{Rails.root}/", '') }
      add_filter   { |line| line.sub(RENDER_TEMPLATE_PATTERN, '') }
      add_filter   { |line| line.sub('./', '/') } # for tests

      add_gem_filters
      add_silencer { |line| line !~ APP_DIRS_PATTERN }
    end

    private
      def add_gem_filters
        return unless defined?(Gem)

        gems_paths = (Gem.path + [Gem.default_dir]).uniq.map!{ |p| Regexp.escape(p) }
        return if gems_paths.empty?

        gems_regexp = %r{(#{gems_paths.join('|')})/gems/([^/]+)-([\w.]+)/(.*)}
        add_filter { |line| line.sub(gems_regexp, '\2 (\3) \4') }
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
