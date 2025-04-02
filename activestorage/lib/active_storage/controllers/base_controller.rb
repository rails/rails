# frozen_string_literal: true

require "active_storage/controllers/set_current"

# The base class for all Active Storage controllers.
class ActiveStorage::BaseController < ActionController::Base
  include ActiveStorage::SetCurrent

  protect_from_forgery with: :exception

  self.etag_with_template_digest = false
end
