require 'date'
require 'active_support/core_ext/object/acts_like'

class DateTime
  # Duck-types as a Date-like and Time-like class. See Object#acts_like?.
  def acts_like?(duck_type)
    duck_type == :date || duck_type == :time
  end
end
