class Topic < ActiveRecord::Base
  scope :base
  scope :written_before, lambda { |time|
    if time
      { :conditions => ['written_on < ?', time] }
    end
  }
  scope :approved, :conditions => {:approved => true}
  scope :rejected, :conditions => {:approved => false}

  scope :scope_with_lambda, lambda { scoped }

  scope :by_lifo, :conditions => {:author_name => 'lifo'}

  scope :approved_as_hash_condition, :conditions => {:topics => {:approved => true}}
  scope 'approved_as_string', :conditions => {:approved => true}
  scope :replied, :conditions => ['replies_count > 0']
  scope :anonymous_extension do
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
  module MultipleExtensionOne
    def extension_one
      1
    end
  end
  module MultipleExtensionTwo
    def extension_two
      2
    end
  end
  scope :named_extension, :extend => NamedExtension
  scope :multiple_extensions, :extend => [MultipleExtensionTwo, MultipleExtensionOne]

  has_many :replies, :dependent => :destroy, :foreign_key => "parent_id"
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

  before_validation :before_validation_for_transaction
  before_save :before_save_for_transaction
  before_destroy :before_destroy_for_transaction

  after_save :after_save_for_transaction
  after_create :after_create_for_transaction

  after_initialize :set_email_address

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
  def blank?
    true
  end
end

module Web
  class Topic < ActiveRecord::Base
    has_many :replies, :dependent => :destroy, :foreign_key => "parent_id", :class_name => 'Web::Reply'
  end
end
