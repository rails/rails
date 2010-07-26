class Liquid < ActiveRecord::Base
  set_table_name :liquid
  has_many :molecules, :uniq => true
end

