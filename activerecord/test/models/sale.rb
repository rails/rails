class Sale < ActiveRecord::Base
  belongs_to :building, autosave: true
  
  before_save :call_another_save, if: -> { message == 'doublesave' }
  
  def call_another_save
    self.building.save
  end
end