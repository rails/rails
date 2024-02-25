# frozen_string_literal: true

# :markup: markdown

module ActionText
  class EncryptedRichText < RichText
    encrypts :body
  end
end

ActiveSupport.run_load_hooks :action_text_encrypted_rich_text, ActionText::EncryptedRichText
