# frozen_string_literal: true

module ActiveRecord
  module Alert
    def alert
      errors.full_messages.to_sentence
    end
  end
end
