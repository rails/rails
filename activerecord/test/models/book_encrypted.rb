# frozen_string_literal: true

require "models/book"

class EncryptedBook < Book
  self.table_name = "books"

  encrypts :name, deterministic: true
end

class EncryptedBookWithDowncaseName < Book
  self.table_name = "books"

  encrypts :name, deterministic: true, downcase: true
end

class EncryptedBookThatIgnoresCase < Book
  self.table_name = "books"

  encrypts :name, deterministic: true, ignore_case: true
end
