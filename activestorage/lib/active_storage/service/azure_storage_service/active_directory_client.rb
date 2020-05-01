# frozen_string_literal: true

gem "adal", "~> 1.0"
gem "azure-storage-blob", "~> 2.0"

require "adal"
require "azure/storage/blob"
require "azure/storage/blob/default"
require "azure/storage/common/core/auth/shared_access_signature"

module ActiveStorage
  # Client that authenticates to Azure Storage via Azure Active Directory
  # See https://docs.microsoft.com/en-us/azure/storage/common/storage-auth-aad
  class Service::AzureStorageService::ActiveDirectoryClient
    attr_reader :storage_account_name, :options, :auth_context, :client_credential
    attr_accessor :user_delegation_key

    def initialize(storage_account_name, **options)
      tenant_id = options.delete(:tenant_id) || ""
      client_id = options.delete(:client_id) || ""
      client_secret = options.delete(:client_secret) || ""

      if tenant_id.empty? || client_id.empty? || client_secret.empty?
        raise ArgumentError, "all of tenant_id, client_id, and client_secret must be provided"
      end

      @storage_account_name = storage_account_name
      @options = options
      @auth_context = ADAL::AuthenticationContext.new("login.microsoftonline.com", tenant_id)
      @client_credential = ADAL::ClientCredential.new(client_id, client_secret)
      @user_delegation_key = nil
    end

    def blob_service
      token = @auth_context.acquire_token_for_client("https://storage.azure.com/", @client_credential)
      token_credential = Azure::Storage::Common::Core::TokenCredential.new token.access_token
      token_signer = Azure::Storage::Common::Core::Auth::TokenSigner.new token_credential
      client = Azure::Storage::Common::Client.create(storage_account_name: @storage_account_name, signer: token_signer)
      Azure::Storage::Blob::BlobService.new(client: client, api_version: "2018-11-09", **@options)
    end

    def shared_access_signature
      if @user_delegation_key.nil? || @user_delegation_key.signed_expiry.to_datetime <= DateTime.now
        now = Time.now
        @user_delegation_key = blob_service.get_user_delegation_key(now - 5.minutes, now + 6.days)
      end
      Azure::Storage::Common::Core::Auth::SharedAccessSignature.new(@storage_account_name, "", @user_delegation_key)
    end
  end
end
