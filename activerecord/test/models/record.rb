class Record < ActiveRecord::Base
end

class RecordWithColumns < Record
  self.table_name = "records"

  has_many :columns, :foreign_key => 'record_id'
end
