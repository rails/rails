# used for OracleSynonymTest, see test/synonym_test_oracle.rb
#
class Subject < ActiveRecord::Base
  protected
    # added initialization of author_email_address in the same way as in Topic class
    # as otherwise synonym test was failing
    def after_initialize
      unless self.persisted?
        self.author_email_address = 'test@test.com'
      end
    end
end
