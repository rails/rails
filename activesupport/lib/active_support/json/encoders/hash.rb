class Hash
  def to_json #:nodoc:
    returning result = '{' do
      result << map do |key, value|
        "#{ActiveSupport::JSON.encode(key)}: #{ActiveSupport::JSON.encode(value)}"
      end * ', '
      result << '}'
    end
  end
end
