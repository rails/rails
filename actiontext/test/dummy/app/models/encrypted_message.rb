class EncryptedMessage < Message
  has_rich_text :content, encrypted: true
end