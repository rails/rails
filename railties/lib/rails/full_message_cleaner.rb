# frozen_string_literal: true

require "active_support/backtrace_cleaner"

module Rails
  class FullMessageCleaner < ActiveSupport::BacktraceCleaner # :nodoc:
    def initialize
      super
      @root ||= Rails.root && "#{Rails.root}/"
      add_filter do |line|
        line = line.sub(@root, "")
        line
      end

      add_silencer { |line| !line.include?(@root) && !line.include?("irb") }
    end

    # Overides to run silencers first, as that simplifies the filter and silencers here
    def clean(backtrace)
      silenced = silence(backtrace)
      filter_backtrace(silenced)
    end
    alias :filter :clean
  end
end
