class Hash
  def to_json #:nodoc:
    returning result = '{' do
      result << map do |key, value|
        key = ActiveSupport::JSON::Variable.new(key.to_s) if 
          ActiveSupport::JSON.can_unquote_identifier?(key)
        "#{ActiveSupport::JSON.encode(key)}: #{ActiveSupport::JSON.encode(value)}"
      end * ', '
      result << '}'
    end
  end
end
