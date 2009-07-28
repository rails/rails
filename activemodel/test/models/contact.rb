class Contact
  attr_accessor :name, :age, :created_at, :awesome, :preferences

  def initialize(options = {})
    options.each { |name, value| send("#{name}=", value) }
  end
end
