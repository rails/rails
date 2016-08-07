# used for OracleSynonymTest, see test/synonym_test_oracle.rb
#
class Subject < ActiveRecord::Base
  # added initialization of author_email_address in the same way as in Topic class
  # as otherwise synonym test was failing
  after_initialize :set_email_address

  protected
    def set_email_address
      unless persisted?
        self.author_email_address = "test@test.com"
      end
    end
end
