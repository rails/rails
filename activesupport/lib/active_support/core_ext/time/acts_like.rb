require 'active_support/core_ext/object/acts_like'

class Time
  # Duck-types as a Time-like class. See Object#acts_like?.
  def acts_like?(duck_type)
    duck_type == :time
  end
end
