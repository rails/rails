# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class RecordSuperclassTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    def test_default_superclass_for_activestorage_record_is_activerecord_base
      app("development")

      assert_equal ActiveRecord::Base, ActiveStorage::Record.superclass
    end

    def test_activestorage_record_superclass_is_configurable
      app_file "app/models/private_application_record.rb", <<~RUBY
        class PrivateApplicationRecord < ::ApplicationRecord
          self.abstract_class = true
        end
      RUBY

      add_to_config <<-RUBY
        config.active_storage.record_superclass = "PrivateApplicationRecord"
      RUBY

      app("development")

      assert_equal PrivateApplicationRecord, ActiveStorage::Record.superclass
    end

    def test_activestorage_record_superclass_config_breaks_if_not_string
      add_to_config <<-RUBY
        config.active_storage.record_superclass = ActiveRecord::Base
      RUBY

      app("development")

      assert_raises NameError do
        ActiveStorage::Record
      end
    end
  end
end
