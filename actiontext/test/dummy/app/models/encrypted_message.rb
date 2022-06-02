class EncryptedMessage < ApplicationRecord
  self.table_name = "messages"

  has_rich_text :content, encrypted: true
end