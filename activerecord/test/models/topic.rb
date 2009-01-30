class Topic < ActiveRecord::Base
  named_scope :base
  named_scope :written_before, lambda { |time|
    { :conditions => ['written_on < ?', time] }
  }
  named_scope :approved, :conditions => {:approved => true}
  named_scope :rejected, :conditions => {:approved => false}

  named_scope :by_lifo, :conditions => {:author_name => 'lifo'}
  
  named_scope :approved_as_hash_condition, :conditions => {:topics => {:approved => true}}
  named_scope 'approved_as_string', :conditions => {:approved => true}
  named_scope :replied, :conditions => ['replies_count > 0']
  named_scope :anonymous_extension do
    def one
      1
    end
  end
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
  named_scope :named_extension, :extend => NamedExtension
  named_scope :multiple_extensions, :extend => [MultipleExtensionTwo, MultipleExtensionOne]

  has_many :replies, :dependent => :destroy, :foreign_key => "parent_id"
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

  protected
    def approved=(val)
      @custom_approved = val
      write_attribute(:approved, val)
    end

    def default_written_on
      self.written_on = Time.now unless attribute_present?("written_on")
    end

    def destroy_children
      self.class.delete_all "parent_id = #{id}"
    end

    def after_initialize
      if self.new_record?
        self.author_email_address = 'test@test.com'
      end
    end
end
