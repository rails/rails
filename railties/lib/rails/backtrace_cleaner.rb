# frozen_string_literal: true

require "active_support/backtrace_cleaner"
require "active_support/core_ext/string/access"

module Rails
  class BacktraceCleaner < ActiveSupport::BacktraceCleaner # :nodoc:
    APP_DIRS_PATTERN = /\A(?:\.\/)?(?:app|config|lib|test|\(\w+(?:-\w+)*\))/
    RENDER_TEMPLATE_PATTERN = /:in [`'].*_\w+_{2,3}\d+_\d+'/

    def initialize
      super
      add_filter do |line|
        # We may be called before Rails.root is assigned.
        # When that happens we fallback to not truncating.
        @root ||= Rails.root && "#{Rails.root}/"
        @root && line.start_with?(@root) ? line.from(@root.size) : line
      end
      add_filter do |line|
        if RENDER_TEMPLATE_PATTERN.match?(line)
          line.sub(RENDER_TEMPLATE_PATTERN, "")
        else
          line
        end
      end
      add_silencer { |line| !APP_DIRS_PATTERN.match?(line) }
    end

    def clean(backtrace, kind = :silent)
      return backtrace if ENV["BACKTRACE"]

      super(backtrace, kind)
    end
    alias_method :filter, :clean

    def clean_frame(frame, kind = :silent)
      return frame if ENV["BACKTRACE"]

      super(frame, kind)
    end
  end
end
