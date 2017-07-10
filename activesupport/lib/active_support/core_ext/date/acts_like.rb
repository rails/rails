# frozen_string_literal: true

require_relative "../object/acts_like"

class Date
  # Duck-types as a Date-like class. See Object#acts_like?.
  def acts_like_date?
    true
  end
end
