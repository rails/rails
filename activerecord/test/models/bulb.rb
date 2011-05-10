class Bulb < ActiveRecord::Base
  default_scope where(:name => 'defaulty')
  belongs_to :car

  attr_protected :car_id, :frickinawesome

  attr_reader :scope_after_initialize

  after_initialize :record_scope_after_initialize
  def record_scope_after_initialize
    @scope_after_initialize = self.class.scoped
  end

end
