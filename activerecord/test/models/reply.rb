require 'models/topic'

class Reply < Topic
  named_scope :base

  belongs_to :topic, :foreign_key => "parent_id", :counter_cache => true
  has_many :replies, :class_name => "SillyReply", :dependent => :destroy, :foreign_key => "parent_id"

  validate :errors_on_empty_content
  validate_on_create :title_is_wrong_create

  attr_accessible :title, :author_name, :author_email_address, :written_on, :content, :last_read

  def validate
    errors.add("title", "Empty")   unless attribute_present? "title"
  end

  def errors_on_empty_content
    errors.add("content", "Empty") unless attribute_present? "content"
  end

  def validate_on_create
    if attribute_present?("title") && attribute_present?("content") && content == "Mismatch"
      errors.add("title", "is Content Mismatch")
    end
  end

  def title_is_wrong_create
    errors.add("title", "is Wrong Create") if attribute_present?("title") && title == "Wrong Create"
  end

  def validate_on_update
    errors.add("title", "is Wrong Update") if attribute_present?("title") && title == "Wrong Update"
  end
end

class SillyReply < Reply
  belongs_to :reply, :foreign_key => "parent_id", :counter_cache => :replies_count
end
