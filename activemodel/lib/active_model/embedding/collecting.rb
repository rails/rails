# frozen_string_literal: true

module ActiveModel
  module Embedding
    module Collecting
      include ActiveModel::ForbiddenAttributesProtection

      attr_reader :documents, :document_class
      alias_method :to_a, :documents
      alias_method :to_ary, :to_a

      def initialize(documents)
        @documents      = documents
        @document_class = documents.first.class
      end

      def attributes=(documents_attributes)
        documents_attributes = sanitize_for_mass_assignment(documents_attributes)

        case documents_attributes
        when Hash
          documents_attributes.each do |index, document_attributes|
            index    = index.to_i
            id       = fetch_id(document_attributes) || index
            document = find_by_id id if id

            unless document
              document = documents[index] || build
            end

            document.attributes = document_attributes
          end
        when Array
          documents_attributes.each do |document_attributes|
            id       = fetch_id(document_attributes)
            document = find_by_id id if id

            unless document
              document = build
            end

            document.attributes = document_attributes
          end
        else
          raise_attributes_error
        end
      end

      def find_by_id(id)
        documents.find { |document| document.id == id }
      end

      def build(attributes = {})
        case attributes
        when Hash
          document = document_class.new(attributes)

          append document

          document
        when Array
          attributes.map do |document_attributes|
            build(document_attributes)
          end
        else
          raise_attributes_error
        end
      end

      def push(*new_documents)
        new_documents = new_documents.flatten

        valid_documents = new_documents.all? { |document| document.is_a? document_class }

        unless valid_documents
          raise ArgumentError, "Expect arguments to be of class #{document_class}"
        end

        @documents.push(*new_documents)
      end

      alias_method :<<, :push
      alias_method :append, :push

      def save
        documents.all?(&:save)
      end

      def each(&block)
        return self.to_enum unless block_given?

        documents.each(&block)
      end

      def as_json
        documents.as_json
      end

      def to_json
        as_json.to_json
      end

      def ==(other)
        documents.map(&:attributes) == other.map(&:attributes)
      end

      private
        def fetch_id(attributes)
          attributes["id"].to_i
        end

        def raise_attributes_error
          raise ArgumentError, "Expect attributes to be a Hash or Array, but got a #{attributes.class}"
        end
    end
  end
end
