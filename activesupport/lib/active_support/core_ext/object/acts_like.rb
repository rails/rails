# frozen_string_literal: true

require "active_support/deprecation"

class Object
  # Provides a way to check whether some class acts like some other class based on the existence of
  # an appropriately-named marker method.
  #
  # A class that provides the same interface as <tt>SomeClass</tt> may define a marker method named
  # <tt>acts_like_some_class?</tt> to signal its compatibility to callers of
  # <tt>acts_like?(:some_class)</tt>.
  #
  # For example, Active Support extends <tt>Date</tt> to define an <tt>acts_like_date?</tt> method,
  # and extends <tt>Time</tt> to define <tt>acts_like_time?</tt>. As a result, developers can call
  # <tt>x.acts_like?(:time)</tt> and <tt>x.acts_like?(:date)</tt> to test duck-type compatibility,
  # and classes that are able to act like <tt>Time</tt> can also define an <tt>acts_like_time?</tt>
  # method to interoperate.
  #
  # ==== Example: A class that provides the same interface as <tt>String</tt>
  #
  # This class may define:
  #
  #   class Stringish
  #     def acts_like_string?
  #       true
  #     end
  #   end
  #
  # Then client code can query for duck-type-safeness this way:
  #
  #   Stringish.new.acts_like?(:string) # => true
  #
  def acts_like?(duck)
    value = \
      case duck
      when :time
        respond_to?(:acts_like_time?) && acts_like_time?
      when :date
        respond_to?(:acts_like_date?) && acts_like_date?
      when :string
        respond_to?(:acts_like_string?) && acts_like_string?
      else
        acts_like_method = :"acts_like_#{duck}?"
        respond_to?(acts_like_method) && send(acts_like_method)
      end

    return value if ActiveSupport.use_acts_like_return_value

    unless [true, false].include? value
      ActiveSupport::Deprecation.warn(<<~MSG.squish)
        Using acts_like?(#{duck}) without acts_like_#{duck} returning a boolean
        value is deprecated. In Rails 7.2, the return value will always be used.

        To opt into the new behavior, add a boolean return value to acts_like_#{duck},
        and then set config.active_support.use_acts_like_return_value = true
      MSG

      return true
    end

    value
  end
end
