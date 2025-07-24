class Hash
  def deep_compact(remove_blank: false)
    dup.deep_compact!(remove_blank: remove_blank)
  end

  def deep_compact!(remove_blank: false)
    should_prune = lambda do |obj|
      return true  if obj.nil?
      return false unless remove_blank

      case obj
      when String       then obj.strip.empty?
      when Array, Hash  then obj.empty?
      else                   false
      end
    end

    each_key.to_a.each do |key|
      value = self[key]

      case value
      when Hash  then value.deep_compact!(remove_blank: remove_blank)
      when Array then deep_compact_array!(value, should_prune, remove_blank)
      end

      delete(key) if should_prune.call(value)
    end

    self
  end

  private

  def deep_compact_array!(array, should_prune, remove_blank)
    array.map! do |element|
      case element
      when Hash  then element.deep_compact!(remove_blank: remove_blank)
      when Array then deep_compact_array!(element, should_prune, remove_blank)
      else            element
      end
    end

    array.reject!(&should_prune)
    array
  end
end
