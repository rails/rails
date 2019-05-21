# frozen_string_literal: true

require "active_support/backtrace_cleaner"

module Rails
  class BacktraceCleaner < ActiveSupport::BacktraceCleaner
    APP_DIRS_PATTERN = /^\/?(app|config|lib|test|\(\w*\))/
    RENDER_TEMPLATE_PATTERN = /:in `.*_\w+_{2,3}\d+_\d+'/
    EMPTY_STRING = ""
    SLASH        = "/"
    DOT_SLASH    = "./"

    def initialize
      super
      @root = "#{Rails.root}/"
      add_filter { |line| line.sub(@root, EMPTY_STRING) }
      add_filter { |line| line.sub(RENDER_TEMPLATE_PATTERN, EMPTY_STRING) }
      add_filter { |line| line.sub(DOT_SLASH, SLASH) } # for tests
      add_silencer { |line| !APP_DIRS_PATTERN.match?(line) }
    end
  end
end
