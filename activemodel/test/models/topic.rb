class Topic
  include ActiveModel::Validations

  attr_accessor :title, :author_name, :content, :approved

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
end
