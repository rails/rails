# frozen_string_literal: true

# The base class for all Active Storage controllers.
class ActiveStorage::BaseController < ActiveStorage.base_controller_parent.constantize
  include ActiveStorage::SetCurrent

  protect_from_forgery with: :exception if respond_to?(:protect_against_forgery?)

  self.etag_with_template_digest = false if respond_to?(:etag_with_template_digest)
end
