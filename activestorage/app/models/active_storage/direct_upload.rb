# frozen_string_literal: true

class ActiveStorage::DirectUpload
  DEFAULT_REQUEST_METHOD = 'put'

  attr_reader :method, :url, :headers

  def initialize(url:, method: DEFAULT_REQUEST_METHOD, headers: {})
    @url = url
    @method = method
    @headers = headers
  end

  def as_json(*)
    { method: method, url: url, headers: headers }
  end
end
