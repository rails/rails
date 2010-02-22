class Contact
  include ActiveModel::Conversion

  attr_accessor :id, :name, :age, :created_at, :awesome, :preferences

  def initialize(options = {})
    options.each { |name, value| send("#{name}=", value) }
  end

  def persisted?
    id
  end
end
