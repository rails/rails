class WithoutTable < ActiveRecord::Base
  def self.default_scope
    where(:published => true)
  end
end
