class Bulb < ActiveRecord::Base
  def self.default_scope
    where :name => 'defaulty'
  end

  belongs_to :car

  attr_reader :scope_after_initialize

  after_initialize :record_scope_after_initialize
  def record_scope_after_initialize
    @scope_after_initialize = self.class.scoped
  end

end
