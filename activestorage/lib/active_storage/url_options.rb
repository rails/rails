# frozen_string_literal: true

module ActiveStorage
  def self.url_options(override_options)
    if ActiveStorage.proxy_urls_host
      { host: ActiveStorage.proxy_urls_host }.merge(override_options || {})
    else
      { only_path: true }.merge(override_options || {})
    end
  end
end
