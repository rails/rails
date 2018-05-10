# frozen_string_literal: true

require "active_model"

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

  def to_js(_options = {})
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
    "#{name}/#{id}"
  end
end

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

class Comment
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  attr_reader :id
  attr_reader :post_id
  def initialize(id = nil, post_id = nil); @id, @post_id = id, post_id end
  def to_key; id ? [id] : nil end
  def save; @id = 1; @post_id = 1 end
  def persisted?; @id.present? end
  def to_param; @id.to_s; end
  def name
    @id.nil? ? "new #{self.class.name.downcase}" : "#{self.class.name.downcase} ##{@id}"
  end

  attr_accessor :relevances
  def relevances_attributes=(attributes); end

  attr_accessor :body
end
