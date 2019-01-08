# frozen_string_literal: true

class ActiveStorage::DirectUpload
  DEFAULT_REQUEST_METHOD = "PUT"

  attr_reader :method, :url, :headers

  def initialize(url:, method: DEFAULT_REQUEST_METHOD, headers: {})
    @url = url
    @method = method.to_s.upcase
    @headers = headers
  end

  def as_json(*)
    { method: method, url: url, headers: headers }
  end
end
