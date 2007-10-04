class Hash
  def to_json(options = {}) #:nodoc:
    hash_keys = self.keys

    if options[:except]
      hash_keys = hash_keys - Array(options[:except])
    elsif options[:only]
      hash_keys = hash_keys & Array(options[:only])
    end

    returning result = '{' do
      result << hash_keys.map do |key|
        "#{ActiveSupport::JSON.encode(key)}: #{ActiveSupport::JSON.encode(self[key], options)}"
      end * ', '
      result << '}'
    end
  end
end
