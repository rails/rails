class Topic < ActiveRecord::Base
  scope :base, -> { all }
  scope :written_before, lambda { |time|
    if time
      where 'written_on < ?', time
    end
  }
  scope :approved, -> { where(:approved => true) }
  scope :rejected, -> { where(:approved => false) }

  scope :scope_with_lambda, lambda { all }

  scope :by_lifo, -> { where(:author_name => 'lifo') }
  scope :replied, -> { where 'replies_count > 0' }

  scope 'approved_as_string', -> { where(:approved => true) }
  scope :anonymous_extension, -> { all } do
    def one
      1
    end
  end

  scope :with_object, Class.new(Struct.new(:klass)) {
    def call
      klass.where(:approved => true)
    end
  }.new(self)

  module NamedExtension
    def two
      2
    end
  end

  has_many :replies, :dependent => :destroy, :foreign_key => "parent_id"
  has_many :approved_replies, -> { approved }, class_name: 'Reply', foreign_key: "parent_id", counter_cache: 'replies_count'
  has_many :replies_with_primary_key, :class_name => "Reply", :dependent => :destroy, :primary_key => "title", :foreign_key => "parent_title"

  has_many :unique_replies, :dependent => :destroy, :foreign_key => "parent_id"
  has_many :silly_unique_replies, :dependent => :destroy, :foreign_key => "parent_id"

  serialize :content

  before_create  :default_written_on
  before_destroy :destroy_children

  # Explicitly define as :date column so that returned Oracle DATE values would be typecasted to Date and not Time.
  # Some tests depend on assumption that this attribute will have Date values.
  if current_adapter?(:OracleEnhancedAdapter)
    set_date_columns :last_read
  end

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

  class_attribute :after_initialize_called
  after_initialize do
    self.class.after_initialize_called = true
  end

  def approved=(val)
    @custom_approved = val
    write_attribute(:approved, val)
  end

  protected

    def default_written_on
      self.written_on = Time.now unless attribute_present?("written_on")
    end

    def destroy_children
      self.class.delete_all "parent_id = #{id}"
    end

    def set_email_address
      unless self.persisted?
        self.author_email_address = 'test@test.com'
      end
    end

    def before_validation_for_transaction; end
    def before_save_for_transaction; end
    def before_destroy_for_transaction; end
    def after_save_for_transaction; end
    def after_create_for_transaction; end
end

class ImportantTopic < Topic
  serialize :important, Hash
end

class BlankTopic < Topic
  # declared here to make sure that dynamic finder with a bang can find a model that responds to `blank?`
  def blank?
    true
  end
end

module Web
  class Topic < ActiveRecord::Base
    has_many :replies, :dependent => :destroy, :foreign_key => "parent_id", :class_name => 'Web::Reply'
  end
end
