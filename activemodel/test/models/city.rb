class City
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks

  attr_accessor :name

  validate :check_empty_name

  def check_empty_name
    errors[:title] << "" unless name && name.size > 0
  end
end
