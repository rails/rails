require "active_model"

class Customer < Struct.new(:name, :id)
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  undef_method :to_json

  def to_param
    id.to_s
  end

  def to_xml(options={})
    if options[:builder]
      options[:builder].name name
    else
      "<name>#{name}</name>"
    end
  end

  def to_js(options={})
    "name: #{name.inspect}"
  end

  def errors
    []
  end

  def destroyed?
    false
  end
end

class BadCustomer < Customer
end

class GoodCustomer < Customer
end

module Quiz
  class Question < Struct.new(:name, :id)
    extend ActiveModel::Naming
    include ActiveModel::Conversion

    def to_param
      id.to_s
    end
  end

  class Store < Question
  end
end

