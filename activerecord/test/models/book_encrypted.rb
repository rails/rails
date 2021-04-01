# frozen_string_literal: true

require "models/book"

class EncryptedBook < ActiveRecord::Base
  self.table_name = "books"

  encrypts :name, deterministic: true
end

class EncryptedBookWithDowncaseName < ActiveRecord::Base
  self.table_name = "books"

  validates :name, uniqueness: true
  encrypts :name, deterministic: true, downcase: true
end

class EncryptedBookThatIgnoresCase < ActiveRecord::Base
  self.table_name = "books"

  encrypts :name, deterministic: true, ignore_case: true
end
