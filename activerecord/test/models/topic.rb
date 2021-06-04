# frozen_string_literal: true

class Topic < ActiveRecord::Base
  scope :base, -> { all }
  scope :written_before, lambda { |time|
    if time
      where "written_on < ?", time
    end
  }
  scope :approved, -> { where(approved: true) }
  scope :rejected, -> { where(approved: false) }

  scope :true, -> { where(approved: true) }
  scope :false, -> { where(approved: false) }

  scope :children, -> { where.not(parent_id: nil) }
  scope :has_children, -> { where(id: Topic.children.select(:parent_id)) }

  scope :scope_with_lambda, lambda { all }

  scope :by_lifo, -> { where(author_name: "lifo") }
  scope :replied, -> { where "replies_count > 0" }

  scope "approved_as_string", -> { where(approved: true) }
  scope :anonymous_extension, -> { } do
    def one
      1
    end
  end

  scope :scope_stats, -> stats { stats[:count] = count; self }

  def self.klass_stats(stats); stats[:count] = count; self; end

  scope :with_object, Class.new(Struct.new(:klass)) {
    def call
      klass.where(approved: true)
    end
  }.new(self)

  scope :with_kwargs, ->(approved: false) { where(approved: approved) }

  module NamedExtension
    def two
      2
    end
  end

  has_many :replies, dependent: :destroy, foreign_key: "parent_id", autosave: true
  has_many :approved_replies, -> { approved }, class_name: "Reply", foreign_key: "parent_id", counter_cache: "replies_count"
  has_many :open_replies, -> { open }, class_name: "Reply", foreign_key: "parent_id"

  has_many :unique_replies, dependent: :destroy, foreign_key: "parent_id"
  has_many :silly_unique_replies, dependent: :destroy, foreign_key: "parent_id"

  serialize :content

  before_create  :default_written_on
  before_destroy :destroy_children

  def parent
    Topic.find(parent_id)
  end

  # trivial method for testing Array#to_xml with :methods
  def topic_id
    id
  end

  alias_attribute :heading, :title

  before_validation :before_validation_for_transaction
  before_save :before_save_for_transaction
  before_destroy :before_destroy_for_transaction

  after_save :after_save_for_transaction
  after_create :after_create_for_transaction

  after_initialize :set_email_address

  attr_accessor :change_approved_before_save
  before_save :change_approved_callback

  class_attribute :after_initialize_called
  after_initialize do
    self.class.after_initialize_called = true
  end

  attr_accessor :after_touch_called

  after_initialize do
    self.after_touch_called = 0
  end

  after_touch do
    self.after_touch_called += 1
  end

  def approved=(val)
    @custom_approved = val
    write_attribute(:approved, val)
  end

  def self.nested_scoping(scope)
    scope.base
  end

  private
    def default_written_on
      self.written_on = Time.now unless attribute_present?("written_on")
    end

    def destroy_children
      self.class.delete_by(parent_id: id)
    end

    def set_email_address
      unless persisted? || will_save_change_to_author_email_address?
        self.author_email_address = "test@test.com"
      end
    end

    def before_validation_for_transaction; end
    def before_save_for_transaction; end
    def before_destroy_for_transaction; end
    def after_save_for_transaction; end
    def after_create_for_transaction; end

    def change_approved_callback
      self.approved = change_approved_before_save unless change_approved_before_save.nil?
    end
end

class DefaultRejectedTopic < Topic
  default_scope -> { where(approved: false) }
end

class BlankTopic < Topic
  # declared here to make sure that dynamic finder with a bang can find a model that responds to `blank?`
  def blank?
    true
  end
end

class TitlePrimaryKeyTopic < Topic
  self.primary_key = :title
end

module Web
  class Topic < ActiveRecord::Base
    has_many :replies, dependent: :destroy, foreign_key: "parent_id", class_name: "Web::Reply"
  end
end
