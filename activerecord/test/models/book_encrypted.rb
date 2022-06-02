# frozen_string_literal: true

class UnencryptedBook < ActiveRecord::Base
  self.table_name = "encrypted_books"
end

class EncryptedBook < ActiveRecord::Base
  self.table_name = "encrypted_books"

  encrypts :name, deterministic: true
end

class EncryptedBookWithDowncaseName < ActiveRecord::Base
  self.table_name = "encrypted_books"

  validates :name, uniqueness: true
  encrypts :name, deterministic: true, downcase: true
end

class EncryptedBookThatIgnoresCase < ActiveRecord::Base
  self.table_name = "encrypted_books"

  encrypts :name, deterministic: true, ignore_case: true
end
