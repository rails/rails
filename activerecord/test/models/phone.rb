class Phone < ActiveRecord::Base
  belongs_to:guy, :foreign_key => :guy_id
end
