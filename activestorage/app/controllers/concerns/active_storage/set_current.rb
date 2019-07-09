# frozen_string_literal: true

# Sets the <tt>ActiveStorage::Current.host</tt> attribute, which the disk service uses to generate URLs.
# Include this concern in custom controllers that call ActiveStorage::Blob#service_url,
# ActiveStorage::Variant#service_url, or ActiveStorage::Preview#service_url so the disk service can
# generate URLs using the same host, protocol, and base path as the current request.
module ActiveStorage::SetCurrent
  extend ActiveSupport::Concern

  included do
    before_action do
      ActiveStorage::Current.host = request.base_url
    end
  end
end
