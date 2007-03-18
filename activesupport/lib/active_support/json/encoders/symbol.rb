class Symbol
  def to_json #:nodoc:
    ActiveSupport::JSON.encode(to_s)
  end
end
