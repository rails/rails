# frozen_string_literal: true

class PrefixedDirectUploadsController < ActiveStorage::DirectUploadsController
  private
    def direct_upload_prefix
      [ super, request.headers["X-Tenant-ID"] ]
    end
end
