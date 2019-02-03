module ActiveStorage
  class DirectUpload

    def initialize(blob)
      @blob = blob

      @method = @blob.service_method_for_direct_upload
      @url = @blob.service_url_for_direct_upload
      @headers = @blob.service_headers_for_direct_upload
    end

    def as_json
      { method: @method, url: @url, headers: @headers }
    end

  end
end
