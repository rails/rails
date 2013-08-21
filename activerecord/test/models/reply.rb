require 'models/topic'

class Reply < Topic
  belongs_to :topic, :foreign_key => "parent_id", :counter_cache => true
  belongs_to :topic_with_primary_key, :class_name => "Topic", :primary_key => "title", :foreign_key => "parent_title", :counter_cache => "replies_count"
  has_many :replies, :class_name => "SillyReply", :dependent => :destroy, :foreign_key => "parent_id"
end

class UniqueReply < Reply
  belongs_to :topic, :foreign_key => 'parent_id', :counter_cache => true
  validates_uniqueness_of :content, :scope => 'parent_id'
end

class SillyUniqueReply < UniqueReply
end

class WrongReply < Reply
  validate :errors_on_empty_content
  validate :title_is_wrong_create, :on => :create

  validate :check_empty_title
  validate :check_content_mismatch, :on => :create
  validate :check_wrong_update, :on => :update
  validate :check_author_name_is_secret, :on => :special_case

  def check_empty_title
    errors[:title] << "Empty" unless attribute_present?("title")
  end

  def errors_on_empty_content
    errors[:content] << "Empty" unless attribute_present?("content")
  end

  def check_content_mismatch
    if attribute_present?("title") && attribute_present?("content") && content == "Mismatch"
      errors[:title] << "is Content Mismatch"
    end
  end

  def title_is_wrong_create
    errors[:title] << "is Wrong Create" if attribute_present?("title") && title == "Wrong Create"
  end

  def check_wrong_update
    errors[:title] << "is Wrong Update" if attribute_present?("title") && title == "Wrong Update"
  end

  def check_author_name_is_secret
    errors[:author_name] << "Invalid" unless author_name == "secret"
  end
end

class SillyReply < Reply
  belongs_to :reply, :foreign_key => "parent_id", :counter_cache => :replies_count
end

module Web
  class Reply < Web::Topic
    belongs_to :topic, :foreign_key => "parent_id", :counter_cache => true, :class_name => 'Web::Topic'
  end
end
