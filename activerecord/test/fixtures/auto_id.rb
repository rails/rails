class AutoId < ActiveRecord::Base
  def self.table_name () "auto_id_tests" end
  def self.primary_key () "auto_id" end
end
