require 'active_support/backtrace_cleaner'
require 'rails/gem_dependency'

module Rails
  class BacktraceCleaner < ActiveSupport::BacktraceCleaner
    ERB_METHOD_SIG = /:in `_run_erb_.*/

    RAILS_GEMS   = %w( actionpack activerecord actionmailer activesupport activeresource rails )

    VENDOR_DIRS  = %w( vendor/rails )
    SERVER_DIRS  = %w( lib/mongrel bin/mongrel
                       lib/passenger bin/passenger-spawn-server
                       lib/rack )
    RAILS_NOISE  = %w( script/server )
    RUBY_NOISE   = %w( rubygems/custom_require benchmark.rb )

    ALL_NOISE    = VENDOR_DIRS + SERVER_DIRS + RAILS_NOISE + RUBY_NOISE

    def initialize
      super
      add_filter   { |line| line.sub("#{RAILS_ROOT}/", '') }
      add_filter   { |line| line.sub(ERB_METHOD_SIG, '') }
      add_filter   { |line| line.sub('./', '/') } # for tests

      add_gem_filters

      add_silencer { |line| ALL_NOISE.any? { |dir| line.include?(dir) } }
      add_silencer { |line| RAILS_GEMS.any? { |gem| line =~ /^#{gem} / } }
      add_silencer { |line| line =~ %r(vendor/plugins/[^\/]+/lib) }
    end
    
    
    private
      def add_gem_filters
        Gem.path.each do |path|
          # http://gist.github.com/30430
          add_filter { |line| line.sub(/(#{path})\/gems\/([a-z]+)-([0-9.]+)\/(.*)/, '\2 (\3) \4')}
        end

        vendor_gems_path = Rails::GemDependency.unpacked_path.sub("#{RAILS_ROOT}/",'')
        add_filter { |line| line.sub(/(#{vendor_gems_path})\/([a-z]+)-([0-9.]+)\/(.*)/, '\2 (\3) [v] \4')}
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
