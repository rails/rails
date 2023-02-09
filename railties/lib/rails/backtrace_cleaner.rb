# frozen_string_literal: true

require "active_support/backtrace_cleaner"
require "active_support/core_ext/string/access"

module Rails
  class BacktraceCleaner < ActiveSupport::BacktraceCleaner # :nodoc:
    APP_DIRS_PATTERN = /\A(?:\.\/)?(?:app|config|lib|test|\(\w*\))/
    RENDER_TEMPLATE_PATTERN = /:in `.*_\w+_{2,3}\d+_\d+'/

    def initialize
      super
      @root = "#{Rails.root}/"
      add_filter do |line|
        line.start_with?(@root) ? line.from(@root.size) : line
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
  end
end
