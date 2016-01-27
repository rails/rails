class Topic
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  include ActiveModel::Dirty

  define_attribute_methods :title

  def self._validates_default_keys
    super | [ :message ]
  end

  attr_accessor :title, :author_name, :content, :approved, :created_at
  attr_accessor :after_validation_performed

  after_validation :perform_after_validation

  def initialize(attributes = {})
    attributes.each do |key, value|
      send "#{key}=", value
    end
  end

  def title=(val)
    title_will_change! unless val == @title
    @title = val
  end

  def save
    changes_applied
  end

  def reload!
    clear_changes_information
  end

  def rollback!
    restore_attributes
  end

  def condition_is_true
    true
  end

  def condition_is_true_but_its_not
    false
  end

  def perform_after_validation
    self.after_validation_performed = true
  end

  def my_validation
    errors.add :title, "is missing" unless title
  end

  def my_validation_with_arg(attr)
    errors.add attr, "is missing" unless send(attr)
  end

  def my_word_tokenizer(str)
   str.scan(/\w+/)
  end

end
