class Hash
  def deep_compact(blank: false)
    dup.deep_compact!(blank: blank)
  end

  def deep_compact!(blank: false)
    each_key do |k|
      v = self[k]

      case v
      when Hash
        v.deep_compact!(blank: blank)
        delete(k) if blank ? v.blank? : v.nil?
      when Array
        v.map! do |elem|
          if elem.is_a?(Hash)
            elem.deep_compact!(blank: blank)
            elem
          elsif elem.is_a?(Array)
            deep_compact_array(elem, blank)
          else
            elem
          end
        end
        v.reject! { |elem| blank ? elem.blank? : elem.nil? }
        delete(k) if blank ? v.blank? : v.nil?
      else
        delete(k) if blank ? v.blank? : v.nil?
      end
    end
    self
  end

  private

  def deep_compact_array(arr, blank)
    arr.map! do |elem|
      if elem.is_a?(Hash)
        elem.deep_compact!(blank: blank)
      elsif elem.is_a?(Array)
        deep_compact_array(elem, blank)
      else
        elem
      end
    end
    arr.reject! { |elem| blank ? elem.blank? : elem.nil? }
    arr
  end
end
