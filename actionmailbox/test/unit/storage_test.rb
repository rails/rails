# frozen_string_literal: true

require_relative "../test_helper"

Rails.application.config.active_storage.service = :test
Rails.application.config.action_mailbox.storage_service = :local

module ActionMailbox
  class StorageTest < ActiveSupport::TestCase
    setup do
      @inbound_email = create_inbound_email_from_mail(
        to: "To <test@case.com>",
        from: "Sender from TestCase <sender@test.case.com>",
        subject: "Hello, Testing Case!",
        body: "Hello!"
      )
      @blob         = @inbound_email.raw_email.blob
    end

    test "allow for inbound emails to have different storage services" do
      assert_not @blob.service_name == ActiveStorage::Blob.service.name, "Should be able to differ"
    end

    test "assert storage service is set" do
      assert_equal @blob.service_name, ActionMailbox.storage_service.to_s
      assert_equal ActiveStorage::Blob.service.name, :test
      assert_instance_of ActiveStorage::Service::DiskService, @inbound_email.raw_email.blob.service
    end

    test "assert storage service is not nil" do
      assert_not @blob.service_name == nil
    end
  end
end
