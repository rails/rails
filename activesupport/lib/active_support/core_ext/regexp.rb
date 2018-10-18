# frozen_string_literal: true

class Regexp #:nodoc:
  def multiline?
    options & MULTILINE == MULTILINE
  end
end
