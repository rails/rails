# frozen_string_literal: true

class MessageWithoutBlanksWithContentValidation < MessageWithoutBlanks
  validates :content, presence: true
end
