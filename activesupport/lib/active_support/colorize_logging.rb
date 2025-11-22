# frozen_string_literal: true

module ActiveSupport
  module ColorizeLogging # :nodoc:
    extend ActiveSupport::Concern

    # ANSI sequence modes
    MODES = {
      clear:     0,
      bold:      1,
      italic:    3,
      underline: 4,
    }

    # ANSI sequence colors
    BLACK   = "\e[30m"
    RED     = "\e[31m"
    GREEN   = "\e[32m"
    YELLOW  = "\e[33m"
    BLUE    = "\e[34m"
    MAGENTA = "\e[35m"
    CYAN    = "\e[36m"
    WHITE   = "\e[37m"

    def info(progname = nil, &block)
      logger.info(progname, &block) if logger
    end

    def debug(progname = nil, &block)
      logger.debug(progname, &block) if logger
    end

    def warn(progname = nil, &block)
      logger.warn(progname, &block) if logger
    end

    def error(progname = nil, &block)
      logger.error(progname, &block) if logger
    end

    def fatal(progname = nil, &block)
      logger.fatal(progname, &block) if logger
    end

    def unknown(progname = nil, &block)
      logger.unknown(progname, &block) if logger
    end

    # Set color by using a symbol or one of the defined constants. Set modes
    # by specifying bold, italic, or underline options. Inspired by Highline,
    # this method will automatically clear formatting at the end of the returned String.
    def color(text, color, mode_options = {}) # :doc:
      return text unless colorize_logging
      color = self.class.const_get(color.upcase) if color.is_a?(Symbol)
      mode = mode_from(mode_options)
      clear = "\e[#{MODES[:clear]}m"
      "#{mode}#{color}#{text}#{clear}"
    end

    def mode_from(options)
      modes = MODES.values_at(*options.compact_blank.keys)

      "\e[#{modes.join(";")}m" if modes.any?
    end

    def colorize_logging
      ActiveSupport.colorize_logging
    end
  end
end
