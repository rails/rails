class Rat < ActiveRecord::Base
  default_scope -> { where(id: 1) }
end
