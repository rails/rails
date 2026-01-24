class MessageWithoutBlanks < ApplicationRecord
  self.table_name = Message.table_name
  
  has_rich_text :content, store_if_blank: false
end
