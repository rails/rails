class Object
  # Returns +value+ after yielding +value+ to the block. This simplifies the
  # process of constructing an object, performing work on the object, and then
  # returning the object from a method. It is a Ruby-ized realization of the K
  # combinator, courtesy of Mikael Brockman.
  #
  # ==== Examples
  #
  #  # Without returning
  #  def foo
  #    values = []
  #    values << "bar"
  #    values << "baz"
  #    return values
  #  end
  #
  #  foo # => ['bar', 'baz']
  #
  #  # returning with a local variable
  #  def foo
  #    returning values = [] do
  #      values << 'bar'
  #      values << 'baz'
  #    end
  #  end
  #
  #  foo # => ['bar', 'baz']
  #  
  #  # returning with a block argument
  #  def foo
  #    returning [] do |values|
  #      values << 'bar'
  #      values << 'baz'
  #    end
  #  end
  #  
  #  foo # => ['bar', 'baz']
  def returning(value)
    yield(value)
    value
  end

  # An elegant way to factor duplication out of options passed to a series of
  # method calls. Each method called in the block, with the block variable as
  # the receiver, will have its options merged with the default +options+ hash
  # provided. Each method called on the block variable must take an options
  # hash as its final argument.
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
