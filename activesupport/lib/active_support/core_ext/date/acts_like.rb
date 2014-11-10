require 'active_support/core_ext/object/acts_like'

class Date
  # Duck-types as a Date-like class. See Object#acts_like?.
  def acts_like?(duck_type)
    duck_type == :date
  end
end
