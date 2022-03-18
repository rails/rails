# frozen_string_literal: true

class ActiveStorage::Current < ActiveSupport::CurrentAttributes # :nodoc:
  attribute :url_options

  def host=(host)
    ActiveSupport::Deprecation.warn("ActiveStorage::Current.host= is deprecated, instead use ActiveStorage::Current.url_options=")
    self.url_options = { host: host }
  end

  def host
    ActiveSupport::Deprecation.warn("ActiveStorage::Current.host is deprecated, instead use ActiveStorage::Current.url_options")
    self.url_options&.dig(:host)
  end
end
