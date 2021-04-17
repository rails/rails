# frozen_string_literal: true

module ActionText
  class EncryptedRichText < RichText
    self.table_name = "action_text_rich_texts"

    encrypts :body
  end
end
