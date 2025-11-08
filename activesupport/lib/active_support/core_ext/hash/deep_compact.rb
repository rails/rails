# frozen_string_literal: true

class Hash
  # Returns a new hash with all nil values removed recursively.
  # This includes the values from the root hash and from all
  # nested hashes and arrays.
  #
  #   hash = { a: 1, b: nil, c: { d: 2, e: nil } }
  #
  #   hash.deep_compact
  #   # => { a: 1, c: { d: 2 } }
  def deep_compact
    _deep_compact_in_object(self)
  end

  # Destructively removes all nil values recursively.
  # This includes the values from the root hash and from all
  # nested hashes and arrays.
  def deep_compact!
    _deep_compact_in_object!(self)
  end

  # Returns a new hash with all blank values removed recursively.
  # This includes the values from the root hash and from all
  # nested hashes and arrays. Uses Object#blank? for determining
  # if a value is blank.
  #
  #   hash = { a: 1, b: "", c: nil, d: [], e: false, f: { g: "", h: 2 } }
  #
  #   hash.deep_compact_blank
  #   # => { a: 1, f: { h: 2 } }
  def deep_compact_blank
    _deep_compact_blank_in_object(self)
  end

  # Destructively removes all blank values recursively.
  # This includes the values from the root hash and from all
  # nested hashes and arrays. Uses Object#blank? for determining
  # if a value is blank.
  def deep_compact_blank!
    _deep_compact_blank_in_object!(self)
  end

  private
    # Support methods for deep compacting nested hashes and arrays.
    def _deep_compact_in_object(object)
      case object
      when Hash
        object.each_with_object({}) do |(key, value), result|
          compacted_value = _deep_compact_in_object(value)
          result[key] = compacted_value unless compacted_value.nil?
        end
      when Array
        object.map { |e| _deep_compact_in_object(e) }
      else
        object
      end
    end

    def _deep_compact_in_object!(object)
      case object
      when Hash
        object.delete_if do |_key, value|
          _deep_compact_in_object!(value)
          value.nil?
        end
      when Array
        object.map! { |e| _deep_compact_in_object!(e) }
      else
        object
      end
    end

    def _deep_compact_blank_in_object(object)
      case object
      when Hash
        object.each_with_object({}) do |(key, value), result|
          compacted_value = _deep_compact_blank_in_object(value)
          result[key] = compacted_value unless compacted_value.blank?
        end
      when Array
        object.map { |e| _deep_compact_blank_in_object(e) }
      else
        object
      end
    end

    def _deep_compact_blank_in_object!(object)
      case object
      when Hash
        object.delete_if do |_key, value|
          _deep_compact_blank_in_object!(value)
          value.blank?
        end
      when Array
        object.map! { |e| _deep_compact_blank_in_object!(e) }
      else
        object
      end
    end
end

