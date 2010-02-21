class Contact
  include ActiveModel::Conversion

  attr_accessor :id, :name, :age, :created_at, :awesome, :preferences, :new_record

  def initialize(options = {})
    options.each { |name, value| send("#{name}=", value) }
  end

  def new_record?
    defined?(@new_record) ? @new_record : true
  end
end
