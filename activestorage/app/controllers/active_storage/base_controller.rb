# frozen_string_literal: true

# The base class for all Active Storage controllers.
class ActiveStorage::BaseController < ActionController::Base
  include ActiveStorage::SetCurrent

  protect_from_forgery with: :exception

  private
    def stream(blob)
      blob.download do |chunk|
        response.stream.write chunk
      end
    ensure
      response.stream.close
    end
end
