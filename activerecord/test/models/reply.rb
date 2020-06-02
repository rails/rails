# frozen_string_literal: true

require "models/topic"

class Reply < Topic
  belongs_to :topic, foreign_key: "parent_id", counter_cache: true
  belongs_to :topic_with_primary_key, class_name: "Topic", primary_key: "title", foreign_key: "parent_title", counter_cache: "replies_count", touch: true
  has_many :replies, class_name: "SillyReply", dependent: :destroy, foreign_key: "parent_id"
  has_many :silly_unique_replies, dependent: :destroy, foreign_key: "parent_id"

  scope :ordered, -> { Reply.order(:id) }

  # Method on Kernel
  def self.open
    approved
  end

  # Methods both on Kernel and Relation
  def self.load(data:); end
  def self.select(data:); end
end

class SillyReply < Topic
  belongs_to :reply, foreign_key: "parent_id", counter_cache: :replies_count
end

class UniqueReply < Reply
  belongs_to :topic, foreign_key: "parent_id", counter_cache: true
  validates_uniqueness_of :content, scope: "parent_id"
end

class SillyUniqueReply < UniqueReply
  validates :content, uniqueness: true
end

class WrongReply < Reply
  validate :errors_on_empty_content
  validate :title_is_wrong_create, on: :create

  validate :check_empty_title
  validate :check_content_mismatch, on: :create
  validate :check_wrong_update, on: :update
  validate :check_author_name_is_secret, on: :special_case

  def check_empty_title
    errors.add(:title, "Empty") unless attribute_present?("title")
  end

  def errors_on_empty_content
    errors.add(:content, "Empty") unless attribute_present?("content")
  end

  def check_content_mismatch
    if attribute_present?("title") && attribute_present?("content") && content == "Mismatch"
      errors.add(:title, "is Content Mismatch")
    end
  end

  def title_is_wrong_create
    errors.add(:title, "is Wrong Create") if attribute_present?("title") && title == "Wrong Create"
  end

  def check_wrong_update
    errors.add(:title, "is Wrong Update") if attribute_present?("title") && title == "Wrong Update"
  end

  def check_author_name_is_secret
    errors.add(:author_name, "Invalid") unless author_name == "secret"
  end
end

module Web
  class Reply < Web::Topic
    belongs_to :topic, foreign_key: "parent_id", counter_cache: true, class_name: "Web::Topic"
  end
end
