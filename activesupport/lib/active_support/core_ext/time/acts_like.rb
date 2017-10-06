# frozen_string_literal: true

require_relative "../object/acts_like"

class Time
  # Duck-types as a Time-like class. See Object#acts_like?.
  def acts_like_time?
    true
  end
end
