# frozen_string_literal: true

# Take a signed permanent reference for a blob and turn it into an expiring service URL for download.
# Note: These URLs are publicly accessible. If you need to enforce access protection beyond the
# security-through-obscurity factor of the signed blob references, you'll need to implement your own
# authenticated redirection controller.
class ActiveStorage::BlobsController < ActionController::Base
  def show
    if blob = find_signed_blob
      params[:no_redirect] ? data_response(blob) : redirect_response(blob)
    else
      head :not_found
    end
  end

  private
    def find_signed_blob
      ActiveStorage::Blob.find_signed(params[:signed_id])
    end

    def disposition_param
      params[:disposition].presence_in(%w( inline attachment )) || "inline"
    end

    def filename_param
      params[:filename].presence || File.basename(@service_url)
    end

    def type_param
      params[:type].presence || Mime::Type.lookup_by_extension(File.extname(@service_url).split(".").last).to_s
    end

    def data_response(blob)
      @service_url = blob.service_url(disposition: "inline")
      send_data open(@service_url).read, disposition: disposition_param, filename: filename_param, type: type_param
    end

    def redirect_response(blob)
      expires_in 5.minutes # service_url defaults to 5 minutes
      redirect_to blob.service_url(disposition: disposition_param)
    end
end
