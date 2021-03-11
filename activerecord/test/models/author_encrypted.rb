# frozen_string_literal: true

require "models/author"

class EncryptedAuthor < Author
  self.table_name = "authors"

  encrypts :name, key: "my very own key", previous: { deterministic: true }
end
