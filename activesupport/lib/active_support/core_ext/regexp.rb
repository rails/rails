class Regexp #:nodoc:
  def multiline?
    options & MULTILINE == MULTILINE
  end
end
