class Hash
  # Returns a JSON string representing the hash.
  #
  # Without any +options+, the returned JSON string will include all
  # the hash keys. For example:
  #
  #   { :name => "Konata Izumi", 'age' => 16, 1 => 2 }.to_json
  #
  #   {"name": "Konata Izumi", 1: 2, "age": 16}
  #
  # The keys in the JSON string are unordered due to the nature of hashes.
  #
  # The <tt>:only</tt> and <tt>:except</tt> options can be used to limit the
  # attributes included, and will accept 1 or more hash keys to include/exclude.
  #
  #   { :name => "Konata Izumi", 'age' => 16, 1 => 2 }.to_json(:only => [:name, 'age'])
  #
  #   {"name": "Konata Izumi", "age": 16}
  #
  #   { :name => "Konata Izumi", 'age' => 16, 1 => 2 }.to_json(:except => 1)
  #
  #   {"name": "Konata Izumi", "age": 16}
  #
  # The +options+ also filter down to any hash values. This is particularly
  # useful for converting hashes containing ActiveRecord objects or any object
  # that responds to options in their <tt>to_json</tt> method. For example:
  #
  #   users = User.find(:all)
  #   { :users => users, :count => users.size }.to_json(:include => :posts)
  #
  # would pass the <tt>:include => :posts</tt> option to <tt>users</tt>,
  # allowing the posts association in the User model to be converted to JSON
  # as well.
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
