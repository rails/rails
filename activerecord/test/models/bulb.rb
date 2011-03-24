class Bulb < ActiveRecord::Base

  default_scope :conditions => {:name => 'defaulty' }

  belongs_to :car

  attr_reader :scoped_methods_after_initialize

  after_initialize :record_scoped_methods_after_initialize
  def record_scoped_methods_after_initialize
    @scoped_methods_after_initialize = self.class.scoped_methods.dup
  end

end
