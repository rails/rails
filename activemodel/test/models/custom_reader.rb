class CustomReader
  include ActiveModel::Validations

  def initialize(data = {})
    @data = data
  end
  
  def []=(key, value)
    @data[key] = value
  end

  private
  
  def read_attribute_for_validation(key)
    @data[key]
  end
end