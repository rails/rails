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
          gem_path_relative_to_root(gem_root) + line.from(gem_root.size)
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
      add_silencer do |line|
        !APP_DIRS_PATTERN.match?(line)
      end
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
    def root
      # We may be called before Rails.root is assigned.
      # When that happens we fallback to not truncating.
      @root ||= Rails.root && "#{Rails.root}/"
    end
    def local_gem_roots
      @local_gem_roots ||= Bundler.definition.sources.path_sources.collect do |spec|
        "#{spec.expanded_original_path}"
      end
    end
    def gem_path_relative_to_root(gem_root)
      return gem_root if root.nil?
      common_path = root.each_char.zip(gem_root.each_char)
                                  .take_while { |a, b| a == b }
                                  .map(&:first)
                                  .join

      return gem_root if common_path.size >= root.size # no '../'s for gems nested within rails root

      dir_divergence = root.from(common_path.size).split(File::SEPARATOR).count
      back_path = "..#{File::SEPARATOR}" * dir_divergence
      forward_path = gem_root.from(common_path.size)

      "#{back_path}#{forward_path}"
    end
  end
end
