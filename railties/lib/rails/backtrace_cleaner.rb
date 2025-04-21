# frozen_string_literal: true

require "active_support/backtrace_cleaner"
require "active_support/core_ext/string/access"

module Rails
  class BacktraceCleaner < ActiveSupport::BacktraceCleaner # :nodoc:
    APP_DIRS = "app|config|lib|test"
    APP_DIRS_PATTERN = /\A(?:\.\.\/|(?:\.\/)?(?:#{APP_DIRS}|\(\w+(?:-\w+)*\)))/
    RENDER_TEMPLATE_PATTERN = /:in [`'].*_\w+_{2,3}\d+_\d+'/

    def initialize
      super
      add_filter do |line|
        local_gem_roots.find { |g| line.start_with?(g) }&.then do |gem_root|
          root && relative_gem_path(gem_root) + line.from(gem_root.size)
        end || line
      end
      add_filter do |line|
        root && line.start_with?(root) ? line.from(root.size) : line
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

    private
    # enable shortcircuiting if we are called before Rails.root is assigned
    def root
      @root ||= Rails.root && "#{Rails.root}/"
    end
    def local_gem_roots
      @local_gem_roots ||= Bundler.definition.sources.path_sources.collect do |spec|
        "#{spec.expanded_original_path}"
      end
    end
    def relative_gem_path(gem_root)
      "#{Pathname(gem_root).relative_path_from(Pathname(root))}"
    end
  end
end
