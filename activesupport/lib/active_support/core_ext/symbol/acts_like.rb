# frozen_string_literal: true

require "active_support/core_ext/object/acts_like"

class Symbol
  # Duck-types as a Symbol-like class. See Object#acts_like?.
  def acts_like_symbol?
    true
  end
end
