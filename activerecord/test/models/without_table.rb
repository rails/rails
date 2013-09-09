class WithoutTable < ApplicationRecord
  default_scope -> { where(:published => true) }
end
