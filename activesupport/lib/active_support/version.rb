module ActiveSupport
  module VERSION #:nodoc:
    MAJOR = 3
    MINOR = 1
    TINY  = 0
    PRE   = "beta"

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
  end
end
