# :markup: markdown
# frozen_string_literal: true

class String
  # Enables more predictable duck-typing on String-like classes. See `Object#acts_like?`.
  def acts_like_string?
    true
  end
end
