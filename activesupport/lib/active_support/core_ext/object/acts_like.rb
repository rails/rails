class Object
  # A duck-type assistant method. For example, Active Support extends Date
  # to define an acts_like_date? method, and extends Time to define
  # acts_like_time?. As a result, we can do "x.acts_like?(:time)" and
  # "x.acts_like?(:date)" to do duck-type-safe comparisons, since classes that
  # we want to act like Time simply need to define an acts_like_time? method.
  def acts_like?(duck)
    respond_to? :"acts_like_#{duck}?"
  end
end
