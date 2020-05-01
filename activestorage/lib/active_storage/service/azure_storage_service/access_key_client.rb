# frozen_string_literal: true

gem "azure-storage-blob", "~> 2.0"

require "azure/storage/blob"
require "azure/storage/blob/default"
require "azure/storage/common/core/auth/shared_access_signature"

module ActiveStorage
  # Client that authenticates to Azure Storage via account access keys
  # See https://docs.microsoft.com/en-us/rest/api/storageservices/authorize-with-shared-key
  class Service::AzureStorageService::AccessKeyClient
    attr_reader :blob_service, :shared_access_signature

    def initialize(storage_account_name, storage_access_key, **options)
      @blob_service = Azure::Storage::Blob::BlobService.create(storage_account_name: storage_account_name, storage_access_key: storage_access_key, **options)
      @shared_access_signature = Azure::Storage::Common::Core::Auth::SharedAccessSignature.new(storage_account_name, storage_access_key)
    end
  end
end
