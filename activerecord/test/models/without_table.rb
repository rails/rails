class WithoutTable < ApplicationModel
  default_scope -> { where(:published => true) }
end
