# frozen_string_literal: true

class Contact
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations

  include ActiveModel::Serializers::JSON

  attr_accessor :id, :name, :age, :created_at, :awesome, :preferences
  attr_accessor :address, :friends, :contact

  def social
    %w(twitter github)
  end

  def network
    { git: :github }
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

  def attributes=(hash)
    hash.each do |k, v|
      instance_variable_set("@#{k}", v)
    end
  end

  def attributes
    instance_values.except('address', 'friends', 'contact')
  end
end
