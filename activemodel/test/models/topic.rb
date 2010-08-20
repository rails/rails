class Topic
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks

  attr_accessor :title, :author_name, :content, :approved
  attr_accessor :after_validation_performed

  after_validation :perform_after_validation

  def initialize(attributes = {})
    attributes.each do |key, value|
      send "#{key}=", value
    end
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

end
