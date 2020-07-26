# frozen_string_literal: true

# The base class for all Active Storage controllers.
class ActiveStorage::BaseController < ActionController::API
  include ActionController::RequestForgeryProtection
  include ActiveStorage::SetCurrent

  protect_from_forgery with: :exception, if: :protect_against_forgery?

  self.etag_with_template_digest = false

  private
    def stream(blob)
      blob.download do |chunk|
        response.stream.write chunk
      end
    ensure
      response.stream.close
    end

  public

  ActiveSupport.run_load_hooks :active_storage_base_controller, self
end
