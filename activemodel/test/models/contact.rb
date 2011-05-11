class Contact
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  attr_accessor :id, :name, :age, :created_at, :awesome, :preferences

  def social
    %w(twitter github)
  end

  def network
    {:git => :github}
  end

  def initialize(options = {})
    options.each { |name, value| send("#{name}=", value) }
  end

  def pseudonyms
    nil
  end

  def persisted?
    id
  end
end
