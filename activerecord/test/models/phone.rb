class Phone < ActiveRecord::Base

  self.primary_key = :phone_id

  validates_presence_of :number

end
