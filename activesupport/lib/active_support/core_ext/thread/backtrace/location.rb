# :markup: markdown
# frozen_string_literal: true

class Thread::Backtrace::Location # :nodoc:
  def spot(ex)
    ErrorHighlight.spot(ex, backtrace_location: self) if defined?(ErrorHighlight)
  end
end
