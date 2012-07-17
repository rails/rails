class Bulb < ActiveRecord::Base
  default_scope { where(:name => 'defaulty') }
  belongs_to :car

  attr_reader :scope_after_initialize, :attributes_after_initialize

  after_initialize :record_scope_after_initialize
  def record_scope_after_initialize
    @scope_after_initialize = self.class.all
  end

  after_initialize :record_attributes_after_initialize
  def record_attributes_after_initialize
    @attributes_after_initialize = attributes.dup
  end

  def color=(color)
    self[:color] = color.upcase + "!"
  end

  def self.new(attributes = {}, options = {}, &block)
    bulb_type = (attributes || {}).delete(:bulb_type)

    if options && options[:as] == :admin && bulb_type.present?
      bulb_class = "#{bulb_type.to_s.camelize}Bulb".constantize
      bulb_class.new(attributes, options, &block)
    else
      super
    end
  end
end

class CustomBulb < Bulb
  after_initialize :set_awesomeness

  def set_awesomeness
    self.frickinawesome = true if name == 'Dude'
  end
end
