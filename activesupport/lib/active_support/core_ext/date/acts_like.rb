require 'date'

class Date
  # Enable more predictable duck-typing on Date-like classes. See
  # Object#acts_like?.
  def acts_like_date?
    true
  end
end
