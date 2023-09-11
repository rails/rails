# frozen_string_literal: true

class ChatMessage < ActiveRecord::Base
end

class ChatMessageCustomPk < ActiveRecord::Base
  self.table_name = "chat_messages_custom_pk"
end
