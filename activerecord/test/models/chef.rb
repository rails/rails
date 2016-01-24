class Chef < ActiveRecord::Base
  belongs_to :employable, polymorphic: true
end

class ChefList < Chef
  belongs_to :employable_list, polymorphic: true
end
