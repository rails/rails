class MessageWithoutBlanksWithContentValidation < MessageWithoutBlanks
  validates :content, presence: true
end
