class TestModel < ActiveRecord::Base
 after_create do
   raise ActiveRecord::StatementInvalid.new("Dead locked")
 end
end