require "active_model"

class Customer < Struct.new(:name, :id)
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  undef_method :to_json

  def to_param
    id.to_s
  end

  def to_xml(options={})
    if options[:builder]
      options[:builder].name name
    else
      "<name>#{name}</name>"
    end
  end

  def to_js(options={})
    "name: #{name.inspect}"
  end

  def errors
    []
  end

  def destroyed?
    false
  end
end

class BadCustomer < Customer
end

class GoodCustomer < Customer
end

module Quiz
  class Question < Struct.new(:name, :id)
    extend ActiveModel::Naming
    include ActiveModel::Conversion

    def to_param
      id.to_s
    end
  end

  class Store < Question
  end
end

class Post < Struct.new(:title, :author_name, :body, :secret, :written_on, :cost)
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  alias_method :secret?, :secret

  def new_record=(boolean)
    @new_record = boolean
  end

  def new_record?
    @new_record
  end

  attr_accessor :author
  def author_attributes=(attributes); end

  attr_accessor :comments
  def comments_attributes=(attributes); end

  attr_accessor :tags
  def tags_attributes=(attributes); end
end

class Comment
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  attr_reader :id
  attr_reader :post_id
  def initialize(id = nil, post_id = nil); @id, @post_id = id, post_id end
  def save; @id = 1; @post_id = 1 end
  def new_record?; @id.nil? end
  def to_param; @id; end
  def name
    @id.nil? ? "new #{self.class.name.downcase}" : "#{self.class.name.downcase} ##{@id}"
  end

  attr_accessor :relevances
  def relevances_attributes=(attributes); end

end

class Tag
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  attr_reader :id
  attr_reader :post_id
  def initialize(id = nil, post_id = nil); @id, @post_id = id, post_id end
  def save; @id = 1; @post_id = 1 end
  def new_record?; @id.nil? end
  def to_param; @id; end
  def value
    @id.nil? ? "new #{self.class.name.downcase}" : "#{self.class.name.downcase} ##{@id}"
  end

  attr_accessor :relevances
  def relevances_attributes=(attributes); end

end

class CommentRelevance
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  attr_reader :id
  attr_reader :comment_id
  def initialize(id = nil, comment_id = nil); @id, @comment_id = id, comment_id end
  def save; @id = 1; @comment_id = 1 end
  def new_record?; @id.nil? end
  def to_param; @id; end
  def value
    @id.nil? ? "new #{self.class.name.downcase}" : "#{self.class.name.downcase} ##{@id}"
  end
end

class TagRelevance
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  attr_reader :id
  attr_reader :tag_id
  def initialize(id = nil, tag_id = nil); @id, @tag_id = id, tag_id end
  def save; @id = 1; @tag_id = 1 end
  def new_record?; @id.nil? end
  def to_param; @id; end
  def value
    @id.nil? ? "new #{self.class.name.downcase}" : "#{self.class.name.downcase} ##{@id}"
  end
end

class Author < Comment
  attr_accessor :post
  def post_attributes=(attributes); end
end
