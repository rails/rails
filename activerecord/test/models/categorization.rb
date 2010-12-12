class Categorization < ActiveRecord::Base
  belongs_to :post
  belongs_to :category
  belongs_to :author
end

class SpecialCategorization < ActiveRecord::Base
  self.table_name = 'categorizations'

  default_scope where(:special => true)

  belongs_to :author
  belongs_to :category
end
