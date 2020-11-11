class ValidatedMessage < Message
  validates :body, presence: true
end
