# frozen_string_literal: true

class Object
  # A duck-type assistant method. For example, Active Support extends Date
  # to define an <tt>acts_like_date?</tt> method, and extends Time to define
  # <tt>acts_like_time?</tt>. As a result, we can do <tt>x.acts_like?(:time)</tt> and
  # <tt>x.acts_like?(:date)</tt> to do duck-type-safe comparisons, since classes that
  # we want to act like Time simply need to define an <tt>acts_like_time?</tt> method.
  def acts_like?(duck)
    case duck
    when :time
      respond_to? :acts_like_time?
    when :date
      respond_to? :acts_like_date?
    when :string
      respond_to? :acts_like_string?
    else
      respond_to? :"acts_like_#{duck}?"
    end
  end
end
