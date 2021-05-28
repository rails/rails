# frozen_string_literal: true

class Object
  # A duck-type assistant method. For example, Active Support extends Date
  # to define an <tt>acts_like_date?</tt> method, and extends Time to define
  # <tt>acts_like_time?</tt>. As a result, we can do <tt>x.acts_like?(:time)</tt> and
  # <tt>x.acts_like?(:date)</tt> to do duck-type-safe comparisons, since classes that
  # we want to act like Time simply need to define an <tt>acts_like_time?</tt>
  # method that returns true.
  def acts_like?(duck)
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
  end
end
