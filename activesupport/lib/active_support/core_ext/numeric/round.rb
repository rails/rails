# <tt>half</tt> option was added to Integer#round and Float#round in Ruby 2.4.
# And a behavior of round was changed to round to even.
# We have depended a behavior of rounding to nearest.
# In some case (i.e. <tt>ActionView::Helpers::DateHelper#distance_of_time_in_words</tt>),
# we have to pass <tt>half: :up</tt> to <tt>round</tt>.
#
# This core_ext enables to us to pass a option,
# even before Ruby 2.3.
if !(0.0.round(0, half: :up) rescue false)
  require "bigdecimal"

  module ActiveSupport::FloatRoundWithOption
    def round(ndigits = 0, half: :even)
      map = {
        even: BigDecimal::ROUND_HALF_EVEN,
        up:   BigDecimal::ROUND_HALF_UP,
        down: BigDecimal::ROUND_HALF_DOWN
      }

      BigDecimal.new(self, Float::DIG).round(ndigits, map[half.to_sym]).to_f
    end
  end

  module ActiveSupport::IntegerRoundWithOption
    def round(ndigits = 0, half: :even)
      map = {
        even: BigDecimal::ROUND_HALF_EVEN,
        up:   BigDecimal::ROUND_HALF_UP,
        down: BigDecimal::ROUND_HALF_DOWN
      }

      if ndigits > 0
        BigDecimal.new(self).round(ndigits, map[half.to_sym]).to_f
      else
        BigDecimal.new(self).round(ndigits, map[half.to_sym]).to_i
      end
    end
  end

  # Ruby 2.4+ unifies Fixnum & Bignum into Integer.
  if 0.class == Integer
    Integer.prepend ActiveSupport::IntegerRoundWithOption
  else
    Fixnum.prepend ActiveSupport::IntegerRoundWithOption
    Bignum.prepend ActiveSupport::IntegerRoundWithOption
  end
  Float.prepend ActiveSupport::FloatRoundWithOption
end
