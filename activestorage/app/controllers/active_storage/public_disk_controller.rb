# frozen_string_literal: true

# Serves files stored in a public disk service using a permanent URL.
class ActiveStorage::PublicDiskController < ActiveStorage::BaseController
  include ActiveStorage::FileServer

  skip_forgery_protection

  def show
    if blob = ActiveStorage::Blob.find_by(key: extract_blob_key)
      if blob.service.public?
        serve_file blob.service.path_for(params[:key]), content_type: blob.content_type, disposition: :inline
      else
        head :unauthorized
      end
    else
      head :not_found
    end
  end

  private
    def extract_blob_key
      if params[:key].start_with? "variant"
        params[:key].split("/")[1]
      else
        params[:key]
      end
    end
end
