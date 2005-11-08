class Author < ActiveRecord::Base
  has_many :posts
  has_many :posts_with_comments, :include => :comments, :class_name => "Post"
  has_many :posts_with_categories, :include => :categories, :class_name => "Post"
  has_many :posts_with_comments_and_categories, :include => [ :comments, :categories ], :order => "posts.id", :class_name => "Post"

  has_many :posts_with_callbacks, :class_name => "Post", :before_add => :log_before_adding,
           :after_add => :log_after_adding, :before_remove => :log_before_removing,
           :after_remove => :log_after_removing
  has_many :posts_with_proc_callbacks, :class_name => "Post",
           :before_add => Proc.new {|o, r| o.post_log << "before_adding#{r.id}"},
           :after_add => Proc.new {|o, r| o.post_log << "after_adding#{r.id}"},
           :before_remove => Proc.new {|o, r| o.post_log << "before_removing#{r.id}"},
           :after_remove => Proc.new {|o, r| o.post_log << "after_removing#{r.id}"}
  has_many :posts_with_multiple_callbacks, :class_name => "Post",
           :before_add => [:log_before_adding, Proc.new {|o, r| o.post_log << "before_adding_proc#{r.id}"}],
           :after_add => [:log_after_adding, Proc.new {|o, r| o.post_log << "after_adding_proc#{r.id}"}]
  has_many :unchangable_posts, :class_name => "Post", :before_add => :raise_exception, :after_add => :log_after_adding

  attr_accessor :post_log

  def after_initialize
    @post_log = []
  end

  private
    def log_before_adding(object)
      @post_log << "before_adding#{object.id}"
    end

    def log_after_adding(object)
      @post_log << "after_adding#{object.id}"
    end

    def log_before_removing(object)
      @post_log << "before_removing#{object.id}"
    end

    def log_after_removing(object)
      @post_log << "after_removing#{object.id}"
    end

    def raise_exception(object)
      raise Exception.new("You can't add a post")
    end
end
