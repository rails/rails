# encoding: utf-8

class Hash
  # Returns a hash with nil and blank values removed.
  # Nested hashes are also cleaned.
  #
  # Example
  #
  #   Hash[:one => 1, :two => nil, :three => 3, :four => { :a => 'a', :b => '' }].clean
  #   # => {:one => 1, :three => 3, :four => { :a => 'a' } }
  #
  def clean
    dup.clean!
  end

  def clean!
    reject! do |key,value|
      if value.is_a?(Hash)
        value.clean!
        value.blank?
      else
        value.is_a?(FalseClass) ? false : value.blank?
      end
    end
    self
  end
end
