require "cases/helper"
require 'models/topic'
require 'models/subject'

# confirm that synonyms work just like tables; in this case
# the "subjects" table in Oracle (defined in oci.sql) is just
# a synonym to the "topics" table

class TestOracleSynonym < ActiveRecord::TestCase

  def test_oracle_synonym
    topic = Topic.new
    subject = Subject.new
    assert_equal(topic.attributes, subject.attributes)
  end

end
