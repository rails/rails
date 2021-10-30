# frozen_string_literal: true

require "active_support/core_ext/callable/parameters"

class Proc
  include Callable::Parameters
end
