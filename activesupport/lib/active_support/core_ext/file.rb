require 'active_support/core_ext/file/atomic'

class File #:nodoc:
  extend ActiveSupport::CoreExtensions::File::Atomic
end
