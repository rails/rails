# frozen_string_literal: true

require 'active_model'

Customer = Struct.new(:name, :id) do
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  undef_method :to_json

  def to_xml(options = {})
    if options[:builder]
      options[:builder].name name
    else
      "<name>#{name}</name>"
    end
  end

  def to_js(options = {})
    "name: #{name.inspect}"
  end
  alias :to_text :to_js

  def errors
    []
  end

  def persisted?
    id.present?
  end

  def cache_key
    name.to_s
  end
end

class BadCustomer < Customer; end
class GoodCustomer < Customer; end

Post = Struct.new(:title, :author_name, :body, :secret, :persisted, :written_on, :cost) do
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  extend ActiveModel::Translation

  alias_method :secret?, :secret
  alias_method :persisted?, :persisted

  def initialize(*args)
    super
    @persisted = false
  end

  attr_accessor :author
  def author_attributes=(attributes); end

  attr_accessor :comments, :comment_ids
  def comments_attributes=(attributes); end

  attr_accessor :tags
  def tags_attributes=(attributes); end
end

class PostDelegator < Post
  def to_model
    PostDelegate.new
  end
end

class PostDelegate < Post
  def self.human_attribute_name(attribute)
    "Delegate #{super}"
  end

  def model_name
    ActiveModel::Name.new(self.class)
  end
end

class Comment
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  attr_reader :id
  attr_reader :post_id
  def initialize(id = nil, post_id = nil); @id, @post_id = id, post_id end
  def to_key; id ? [id] : nil end
  def save; @id = 1; @post_id = 1 end
  def persisted?; @id.present? end
  def to_param; @id && @id.to_s; end
  def name
    @id.nil? ? "new #{self.class.name.downcase}" : "#{self.class.name.downcase} ##{@id}"
  end

  attr_accessor :relevances
  def relevances_attributes=(attributes); end

  attr_accessor :body
end

class Tag
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  attr_reader :id
  attr_reader :post_id
  def initialize(id = nil, post_id = nil); @id, @post_id = id, post_id end
  def to_key; id ? [id] : nil end
  def save; @id = 1; @post_id = 1 end
  def persisted?; @id.present? end
  def to_param; @id && @id.to_s; end
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
  def to_key; id ? [id] : nil end
  def save; @id = 1; @comment_id = 1 end
  def persisted?; @id.present? end
  def to_param; @id && @id.to_s; end
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
  def to_key; id ? [id] : nil end
  def save; @id = 1; @tag_id = 1 end
  def persisted?; @id.present? end
  def to_param; @id && @id.to_s; end
  def value
    @id.nil? ? "new #{self.class.name.downcase}" : "#{self.class.name.downcase} ##{@id}"
  end
end

class Author < Comment
  attr_accessor :post
  def post_attributes=(attributes); end
end

class HashBackedAuthor < Hash
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  def persisted?; false; end

  def name
    'hash backed author'
  end
end

module Blog
  def self.use_relative_model_naming?
    true
  end

  Post = Struct.new(:title, :id) do
    extend ActiveModel::Naming
    include ActiveModel::Conversion

    def persisted?
      id.present?
    end
  end
end

class ArelLike
  def to_ary
    true
  end
  def each
    a = Array.new(2) { |id| Comment.new(id + 1) }
    a.each { |i| yield i }
  end
end

Car = Struct.new(:color)

class Plane
  attr_reader :to_key

  def model_name
    OpenStruct.new param_key: 'airplane'
  end

  def save
    @to_key = [1]
  end
end
