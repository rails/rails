class Object
  # A Ruby-ized realization of the K combinator, courtesy of Mikael Brockman.
  #
  #   def foo
  #     returning values = [] do
  #       values << 'bar'
  #       values << 'baz'
  #     end
  #   end
  #
  #   foo # => ['bar', 'baz']
  #
  #   def foo
  #     returning [] do |values|
  #       values << 'bar'
  #       values << 'baz'
  #     end
  #   end
  #
  #   foo # => ['bar', 'baz']
  #
  def returning(value)
    yield(value)
    value
  end

  # An elegant way to refactor out common options
  # 
  #   with_options :order => 'created_at', :class_name => 'Comment' do |post|
  #     post.has_many :comments, :conditions => ['approved = ?', true], :dependent => :delete_all
  #     post.has_many :unapproved_comments, :conditions => ['approved = ?', false]
  #     post.has_many :all_comments
  #   end
  #
  # Can also be used with an explicit receiver:
  #
  #   map.with_options :controller => "people" do |people|
  #     people.connect "/people",     :action => "index"
  #     people.connect "/people/:id", :action => "show"
  #   end
  #
  def with_options(options)
    yield ActiveSupport::OptionMerger.new(self, options)
  end
  
  # A duck-type assistant method. For example, Active Support extends Date
  # to define an acts_like_date? method, and extends Time to define
  # acts_like_time?. As a result, we can do "x.acts_like?(:time)" and
  # "x.acts_like?(:date)" to do duck-type-safe comparisons, since classes that
  # we want to act like Time simply need to define an acts_like_time? method.
  def acts_like?(duck)
    respond_to? "acts_like_#{duck}?"
  end
end
