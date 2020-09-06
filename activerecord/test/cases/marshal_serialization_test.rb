# frozen_string_literal: true

require 'cases/helper'
require 'models/topic'
require 'models/reply'

class MarshalSerializationTest < ActiveRecord::TestCase
  fixtures :topics

  def test_deserializing_rails_6_0_marshal_basic
    topic = Marshal.load(marshal_fixture('rails_6_0_topic'))

    assert_not_predicate topic, :new_record?
    assert_equal 1, topic.id
    assert_equal 'The First Topic', topic.title
    assert_equal 'Have a nice day', topic.content
  end

  def test_deserializing_rails_6_0_marshal_with_loaded_association_cache
    topic = Marshal.load(marshal_fixture('rails_6_0_topic_associations'))

    assert_not_predicate topic, :new_record?
    assert_equal 1, topic.id
    assert_equal 'The First Topic', topic.title
    assert_equal 'Have a nice day', topic.content
  end

  private
    def marshal_fixture(file_name)
      File.binread(marshal_fixture_path(file_name))
    end

    def marshal_fixture_path(file_name)
      File.expand_path(
        "support/marshal_compatibility_fixtures/#{ActiveRecord::Base.connection.adapter_name}/#{file_name}.dump",
        TEST_ROOT
      )
    end
end
