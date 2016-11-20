require "active_support/backtrace_cleaner"

module Rails
  class BacktraceCleaner < ActiveSupport::BacktraceCleaner
    APP_DIRS_PATTERN = /^\/?(app|config|lib|test|\(\w*\))/
    RENDER_TEMPLATE_PATTERN = /:in `_render_template_\w*'/
    EMPTY_STRING = "".freeze
    SLASH        = "/".freeze
    DOT_SLASH    = "./".freeze

    def initialize
      super
      @root = "#{Rails.root}/".freeze
      add_filter { |line| line.sub(@root, EMPTY_STRING) }
      add_filter { |line| line.sub(RENDER_TEMPLATE_PATTERN, EMPTY_STRING) }
      add_filter { |line| line.sub(DOT_SLASH, SLASH) } # for tests

      add_gem_filters
      add_silencer { |line| line !~ APP_DIRS_PATTERN }
    end

    private
      def add_gem_filters
        gems_paths = (Gem.path | [Gem.default_dir]).map { |p| Regexp.escape(p) }
        return if gems_paths.empty?

        gems_regexp = %r{(#{gems_paths.join('|')})/gems/([^/]+)-([\w.]+)/(.*)}
        gems_result = '\2 (\3) \4'.freeze
        add_filter { |line| line.sub(gems_regexp, gems_result) }
      end
  end
end
