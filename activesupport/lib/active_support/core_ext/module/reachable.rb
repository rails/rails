# frozen_string_literal: true
require_relative "anonymous"
require_relative "../string/inflections"

class Module
  def reachable? #:nodoc:
    !anonymous? && name.safe_constantize.equal?(self)
  end
end
