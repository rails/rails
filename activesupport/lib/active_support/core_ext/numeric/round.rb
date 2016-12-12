# <tt>half</tt> option was added to Integer#round and Float#round in Ruby 2.4.
# And a behavior of round was changed to round to even.
# We have depended a behavior of rounding to nearest.
# In some case (i.e. <tt>ActionView::Helpers::DateHelper#distance_of_time_in_words</tt>),
# we have to pass <tt>half: :up</tt> to <tt>round</tt>.
#
# This core_ext enables to us to pass a option,
# even before Ruby 2.3.
if !(0.0.round(0, half: :up) rescue false)
  module ActiveSupport::NumericRoundWithOption
    def round(ndigits = 0, half: nil)
      super(ndigits)
    end
  end

  # Ruby 2.4+ unifies Fixnum & Bignum into Integer.
  if 0.class == Integer
    Integer.prepend ActiveSupport::NumericRoundWithOption
  else
    Fixnum.prepend ActiveSupport::NumericRoundWithOption
    Bignum.prepend ActiveSupport::NumericRoundWithOption
  end
  Float.prepend ActiveSupport::NumericRoundWithOption
end
