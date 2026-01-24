# frozen_string_literal: true

class Thread::Backtrace::Location # :nodoc:
  def spot(ex)
    ErrorHighlight.spot(ex, backtrace_location: self)
  end
end
