# frozen_string_literal: true

class GlobalID
  attr_reader :uri
  delegate :to_param, :to_s, to: :uri

  def initialize(gid, _options = {})
    @uri = gid
  end
end
