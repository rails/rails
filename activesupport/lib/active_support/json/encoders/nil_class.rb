class NilClass
  AS_JSON = ActiveSupport::JSON::Variable.new('null').freeze

  def as_json(options = nil) #:nodoc:
    AS_JSON
  end
end
