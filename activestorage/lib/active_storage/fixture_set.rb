# frozen_string_literal: true

require "active_support/testing/file_fixtures"
require "active_record/secure_token"

module ActiveStorage
  # = Active Storage \FixtureSet
  #
  # Fixtures are a way of organizing data that you want to test against; in
  # short, sample data.
  #
  # To learn more about fixtures, read the ActiveRecord::FixtureSet documentation.
  #
  # === YAML
  #
  # Like other Active Record-backed models, ActiveStorage::Attachment and
  # ActiveStorage::Blob records inherit from ActiveRecord::Base instances and
  # therefore can be populated by fixtures.
  #
  # Consider a hypothetical <tt>Article</tt> model class, its related
  # fixture data, as well as fixture data for related ActiveStorage::Attachment
  # and ActiveStorage::Blob records:
  #
  #   # app/models/article.rb
  #   class Article < ApplicationRecord
  #     has_one_attached :thumbnail
  #   end
  #
  # <code></code>
  #
  #   # fixtures/active_storage/blobs.yml
  #   first_thumbnail_blob: <%= ActiveStorage::FixtureSet.blob filename: "first.png" %>
  #
  # <code></code>
  #
  #   # fixtures/active_storage/attachments.yml
  #   first_thumbnail_attachment:
  #     name: thumbnail
  #     record: first (Article)
  #     blob: first_thumbnail_blob
  #
  # When processed, Active Record will insert database records for each fixture
  # entry and will ensure the Active Storage relationship is intact.
  class FixtureSet
    include ActiveSupport::Testing::FileFixtures
    include ActiveRecord::SecureToken

    # Generate a YAML-encoded representation of an ActiveStorage::Blob
    # instance's attributes, resolve the file relative to the directory mentioned
    # by ActiveSupport::Testing::FileFixtures.file_fixture, and upload
    # the file to the Service
    #
    # === Examples
    #
    #   # tests/fixtures/active_storage/blobs.yml
    #   second_thumbnail_blob: <%= ActiveStorage::FixtureSet.blob(
    #     filename: "second.svg",
    #   ) %>
    #
    #   third_thumbnail_blob: <%= ActiveStorage::FixtureSet.blob(
    #     filename: "third.svg",
    #     content_type: "image/svg+xml",
    #     service_name: "public"
    #   ) %>
    #
    def self.blob(filename:, **attributes)
      new.prepare Blob.new(filename: filename, key: generate_unique_secure_token), **attributes
    end

    def prepare(instance, **attributes)
      io = file_fixture(instance.filename.to_s).open
      instance.unfurl(io)
      instance.assign_attributes(attributes)
      instance.upload_without_unfurling(io)

      instance.attributes.transform_values { |value| value.is_a?(Hash) ? value.to_json : value }.compact.to_json
    end
  end
end
