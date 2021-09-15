# frozen_string_literal: true

# Sets the <tt>ActiveStorage::Current.url_options</tt> attribute, which the disk service uses to generate URLs.
# Include this concern in custom controllers that call ActiveStorage::Blob#url,
# ActiveStorage::Variant#url, or ActiveStorage::Preview#url so the disk service can
# generate URLs using the same host, protocol, and port as the current request.
module ActiveStorage::SetCurrent
  extend ActiveSupport::Concern

  included do
    before_action do
      ActiveStorage::Current.url_options = { protocol: request.protocol, host: request.host, port: request.port }
    end
  end
end
