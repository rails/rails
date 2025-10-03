# frozen_string_literal: true

module ActionDispatch
  class ParamBuilder
    # --
    # This implementation is based on Rack::QueryParser,
    # Copyright (C) 2007-2021 Leah Neukirchen <http://leahneukirchen.org/infopage.html>

    def self.make_default(param_depth_limit)
      new param_depth_limit
    end

    attr_reader :param_depth_limit

    def initialize(param_depth_limit)
      @param_depth_limit = param_depth_limit
    end

    cattr_accessor :default
    self.default = make_default(100)

    class << self
      delegate :from_query_string, :from_pairs, :from_hash, to: :default

      def ignore_leading_brackets
        ActionDispatch.deprecator.warn <<~MSG
          ActionDispatch::ParamBuilder.ignore_leading_brackets is deprecated and have no effect and will be removed in Rails 8.2.
        MSG

        @ignore_leading_brackets
      end

      def ignore_leading_brackets=(value)
        ActionDispatch.deprecator.warn <<~MSG
          ActionDispatch::ParamBuilder.ignore_leading_brackets is deprecated and have no effect and will be removed in Rails 8.2.
        MSG

        @ignore_leading_brackets = value
      end
    end

    def from_query_string(qs, separator: nil, encoding_template: nil)
      from_pairs QueryParser.each_pair(qs, separator), encoding_template: encoding_template
    end

    def from_pairs(pairs, encoding_template: nil)
      params = make_params

      pairs.each do |k, v|
        if Hash === v
          v = ActionDispatch::Http::UploadedFile.new(v)
        end

        store_nested_param(params, k, v, 0, encoding_template)
      end

      params
    rescue ArgumentError => e
      raise InvalidParameterError, e.message, e.backtrace
    end

    def from_hash(hash, encoding_template: nil)
      # Force encodings from encoding template
      hash = Request::Utils::CustomParamEncoder.encode_for_template(hash, encoding_template)

      # Assert valid encoding
      Request::Utils.check_param_encoding(hash)

      # Convert hashes to HWIA (or UploadedFile), and deep-munge nils
      # out of arrays
      hash = Request::Utils.normalize_encode_params(hash)

      hash
    end

    private
      def store_nested_param(params, name, v, depth, encoding_template = nil)
        raise ParamsTooDeepError if depth >= param_depth_limit

        if !name
          # nil name, treat same as empty string (required by tests)
          k = after = ""
        elsif depth == 0
          # Start of parsing, don't treat [] or [ at start of string specially
          if start = name.index("[", 1)
            # Start of parameter nesting, use part before brackets as key
            k = name[0, start]
            after = name[start, name.length]
          else
            # Plain parameter with no nesting
            k = name
            after = ""
          end
        elsif name.start_with?("[]")
          # Array nesting
          k = "[]"
          after = name[2, name.length]
        elsif name.start_with?("[") && (start = name.index("]", 1))
          # Hash nesting, use the part inside brackets as the key
          k = name[1, start - 1]
          after = name[start + 1, name.length]
        else
          # Probably malformed input, nested but not starting with [
          # treat full name as key for backwards compatibility.
          k = name
          after = ""
        end

        return if k.empty?

        unless k.valid_encoding?
          raise InvalidParameterError, "Invalid encoding for parameter: #{k}"
        end

        if depth == 0 && String === v
          # We have to wait until we've found the top part of the name,
          # because that's what the encoding template is configured with
          if encoding_template && (designated_encoding = encoding_template[k]) && !v.frozen?
            v.force_encoding(designated_encoding)
          end

          # ... and we can't validate the encoding until after we've
          # applied any template override
          unless v.valid_encoding?
            raise InvalidParameterError, "Invalid encoding for parameter: #{v.scrub}"
          end
        end

        if after == ""
          if k == "[]" && depth != 0
            return (v || !ActionDispatch::Request::Utils.perform_deep_munge) ? [v] : []
          else
            params[k] = v
          end
        elsif after == "["
          params[name] = v
        elsif after == "[]"
          params[k] ||= []
          raise ParameterTypeError, "expected Array (got #{params[k].class.name}) for param `#{k}'" unless params[k].is_a?(Array)
          params[k] << v if v || !ActionDispatch::Request::Utils.perform_deep_munge
        elsif after.start_with?("[]")
          # Recognize x[][y] (hash inside array) parameters
          unless after[2] == "[" && after.end_with?("]") && (child_key = after[3, after.length - 4]) && !child_key.empty? && !child_key.index("[") && !child_key.index("]")
            # Handle other nested array parameters
            child_key = after[2, after.length]
          end
          params[k] ||= []
          raise ParameterTypeError, "expected Array (got #{params[k].class.name}) for param `#{k}'" unless params[k].is_a?(Array)
          if params_hash_type?(params[k].last) && !params_hash_has_key?(params[k].last, child_key)
            store_nested_param(params[k].last, child_key, v, depth + 1)
          else
            params[k] << store_nested_param(make_params, child_key, v, depth + 1)
          end
        else
          params[k] ||= make_params
          raise ParameterTypeError, "expected Hash (got #{params[k].class.name}) for param `#{k}'" unless params_hash_type?(params[k])
          params[k] = store_nested_param(params[k], after, v, depth + 1)
        end

        params
      end

      def make_params
        ActiveSupport::HashWithIndifferentAccess.new
      end

      def new_depth_limit(param_depth_limit)
        self.class.new @params_class, param_depth_limit
      end

      def params_hash_type?(obj)
        Hash === obj
      end

      def params_hash_has_key?(hash, key)
        return false if key.include?("[]")

        key.split(/[\[\]]+/).inject(hash) do |h, part|
          next h if part == ""
          return false unless params_hash_type?(h) && h.key?(part)
          h[part]
        end

        true
      end
  end
end
