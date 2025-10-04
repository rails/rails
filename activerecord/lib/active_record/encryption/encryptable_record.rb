# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # This is the concern mixed in Active Record models to make them encryptable. It adds the +encrypts+
    # attribute declaration, as well as the API to encrypt and decrypt records.
    module EncryptableRecord
      extend ActiveSupport::Concern

      included do
        class_attribute :encrypted_attributes

        validate :cant_modify_encrypted_attributes_when_frozen, if: -> { has_encrypted_attributes? && ActiveRecord::Encryption.context.frozen_encryption? }
      end

      class_methods do
        # Encrypts the +name+ attribute.
        #
        # ==== Options
        #
        # * <tt>:key_provider</tt> - A key provider to provide encryption and decryption keys. Defaults to
        #   +ActiveRecord::Encryption.key_provider+.
        # * <tt>:key</tt> - A password to derive the key from. It's a shorthand for a +:key_provider+ that
        #   serves derivated keys. Both options can't be used at the same time.
        # * <tt>:deterministic</tt> - By default, encryption is not deterministic. It will use a random
        #   initialization vector for each encryption operation. This means that encrypting the same content
        #   with the same key twice will generate different ciphertexts. When set to +true+, it will generate the
        #   initialization vector based on the encrypted content. This means that the same content will generate
        #   the same ciphertexts. This enables querying encrypted text with Active Record. Deterministic encryption
        #   will use the oldest encryption scheme to encrypt new data by default. You can change this by setting
        #   <tt>deterministic: { fixed: false }</tt>. That will make it use the newest encryption scheme for encrypting new
        #   data.
        # * <tt>:support_unencrypted_data</tt> - When true, unencrypted data can be read normally. When false, it will raise errors.
        #   Falls back to +config.active_record.encryption.support_unencrypted_data+ if no value is provided.
        #   This is useful for scenarios where you encrypt one column, and want to disable support for unencrypted data
        #   without having to tweak the global setting.
        # * <tt>:downcase</tt> - When true, it converts the encrypted content to downcase automatically. This allows to
        #   effectively ignore case when querying data. Notice that the case is lost. Use +:ignore_case+ if you are interested
        #   in preserving it.
        # * <tt>:ignore_case</tt> - When true, it behaves like +:downcase+ but, it also preserves the original case in a specially
        #   designated column +original_<name>+. When reading the encrypted content, the version with the original case is
        #   served. But you can still execute queries that will ignore the case. This option can only be used when +:deterministic+
        #   is true.
        # * <tt>:context_properties</tt> - Additional properties that will override +Context+ settings when this attribute is
        #   encrypted and decrypted. E.g: +encryptor:+, +cipher:+, +message_serializer:+, etc.
        # * <tt>:previous</tt> - List of previous encryption schemes. When provided, they will be used in order when trying to read
        #   the attribute. Each entry of the list can contain the properties supported by #encrypts. Also, when deterministic
        #   encryption is used, they will be used to generate additional ciphertexts to check in the queries.
        def encrypts(*names, key_provider: nil, key: nil, deterministic: false, support_unencrypted_data: nil, downcase: false, ignore_case: false, previous: [], compress: true, compressor: nil, **context_properties)
          self.encrypted_attributes ||= Set.new # not using :default because the instance would be shared across classes

          names.each do |name|
            encrypt_attribute name, key_provider: key_provider, key: key, deterministic: deterministic, support_unencrypted_data: support_unencrypted_data, downcase: downcase, ignore_case: ignore_case, previous: previous, compress: compress, compressor: compressor, **context_properties
          end
        end

        # Returns the list of deterministic encryptable attributes in the model class.
        def deterministic_encrypted_attributes
          @deterministic_encrypted_attributes ||= encrypted_attributes&.find_all do |attribute_name|
            type_for_attribute(attribute_name).deterministic?
          end
        end

        # Given a attribute name, it returns the name of the source attribute when it's a preserved one.
        def source_attribute_from_preserved_attribute(attribute_name)
          attribute_name.to_s.sub(ORIGINAL_ATTRIBUTE_PREFIX, "") if attribute_name.start_with?(ORIGINAL_ATTRIBUTE_PREFIX)
        end

        private
          def scheme_for(key_provider: nil, key: nil, deterministic: false, support_unencrypted_data: nil, downcase: false, ignore_case: false, previous: [], **context_properties)
            ActiveRecord::Encryption::Scheme.new(key_provider: key_provider, key: key, deterministic: deterministic,
              support_unencrypted_data: support_unencrypted_data, downcase: downcase, ignore_case: ignore_case, **context_properties).tap do |scheme|
              scheme.previous_schemes = global_previous_schemes_for(scheme) +
              Array.wrap(previous).collect { |scheme_config| ActiveRecord::Encryption::Scheme.new(**scheme_config) }
            end
          end

          def global_previous_schemes_for(scheme)
            ActiveRecord::Encryption.config.previous_schemes.filter_map do |previous_scheme|
              scheme.merge(previous_scheme) if scheme.compatible_with?(previous_scheme)
            end
          end

          def encrypt_attribute(name, key_provider: nil, key: nil, deterministic: false, support_unencrypted_data: nil, downcase: false, ignore_case: false, previous: [], compress: true, compressor: nil, **context_properties)
            encrypted_attributes << name.to_sym

            decorate_attributes([name]) do |name, cast_type|
              scheme = scheme_for key_provider: key_provider, key: key, deterministic: deterministic, support_unencrypted_data: support_unencrypted_data, \
                downcase: downcase, ignore_case: ignore_case, previous: previous, compress: compress, compressor: compressor, **context_properties

              ActiveRecord::Encryption::EncryptedAttributeType.new(scheme: scheme, cast_type: cast_type, default: columns_hash[name.to_s]&.default)
            end

            preserve_original_encrypted(name) if ignore_case
            ActiveRecord::Encryption.encrypted_attribute_was_declared(self, name)
          end

          def preserve_original_encrypted(name)
            original_attribute_name = "#{ORIGINAL_ATTRIBUTE_PREFIX}#{name}".to_sym

            if !ActiveRecord::Encryption.config.support_unencrypted_data && !column_names.include?(original_attribute_name.to_s)
              raise Errors::Configuration, "To use :ignore_case for '#{name}' you must create an additional column named '#{original_attribute_name}'"
            end

            encrypts original_attribute_name
            override_accessors_to_preserve_original name, original_attribute_name
          end

          def override_accessors_to_preserve_original(name, original_attribute_name)
            include(Module.new do
              define_method name do
                if ((value = super()) && encrypted_attribute?(name)) || !ActiveRecord::Encryption.config.support_unencrypted_data
                  send(original_attribute_name)
                else
                  value
                end
              end

              define_method "#{name}=" do |value|
                self.send "#{original_attribute_name}=", value
                super(value)
              end
            end)
          end

          def load_schema! # :nodoc:
            super

            add_length_validation_for_encrypted_columns if ActiveRecord::Encryption.config.validate_column_size
          end

          def add_length_validation_for_encrypted_columns
            encrypted_attributes&.each do |attribute_name|
              validate_column_size attribute_name
            end
          end

          def validate_column_size(attribute_name)
            if limit = columns_hash[attribute_name.to_s]&.limit
              validates_length_of attribute_name, maximum: limit
            end
          end
      end

      # Returns whether a given attribute is encrypted or not.
      def encrypted_attribute?(attribute_name)
        name = attribute_name.to_s
        name = self.class.attribute_aliases[name] || name

        return false unless self.class.encrypted_attributes&.include? name.to_sym

        type = type_for_attribute(name)
        type.encrypted? read_attribute_before_type_cast(name)
      end

      # Returns the ciphertext for +attribute_name+.
      def ciphertext_for(attribute_name)
        if encrypted_attribute?(attribute_name)
          read_attribute_before_type_cast(attribute_name)
        else
          read_attribute_for_database(attribute_name)
        end
      end

      # Encrypts all the encryptable attributes and saves the changes.
      def encrypt
        encrypt_attributes if has_encrypted_attributes?
      end

      # Decrypts all the encryptable attributes and saves the changes.
      def decrypt
        decrypt_attributes if has_encrypted_attributes?
      end

      private
        ORIGINAL_ATTRIBUTE_PREFIX = "original_"

        def _create_record(attribute_names = self.attribute_names)
          if has_encrypted_attributes?
            # Always persist encrypted attributes, because an attribute might be
            # encrypting a column default value.
            attribute_names |= self.class.encrypted_attributes.map(&:to_s)
          end
          super
        end

        def encrypt_attributes
          validate_encryption_allowed

          update_columns build_encrypt_attribute_assignments
        end

        def decrypt_attributes
          validate_encryption_allowed

          decrypt_attribute_assignments = build_decrypt_attribute_assignments
          ActiveRecord::Encryption.without_encryption { update_columns decrypt_attribute_assignments }
        end

        def validate_encryption_allowed
          raise ActiveRecord::Encryption::Errors::Configuration, "can't be modified because it is encrypted" if ActiveRecord::Encryption.context.frozen_encryption?
        end

        def has_encrypted_attributes?
          self.class.encrypted_attributes.present?
        end

        def build_encrypt_attribute_assignments
          Array(self.class.encrypted_attributes).index_with do |attribute_name|
            self[attribute_name]
          end
        end

        def build_decrypt_attribute_assignments
          Array(self.class.encrypted_attributes).to_h do |attribute_name|
            type = type_for_attribute(attribute_name)
            encrypted_value = ciphertext_for(attribute_name)
            new_value = type.deserialize(encrypted_value)
            [attribute_name, new_value]
          end
        end

        def cant_modify_encrypted_attributes_when_frozen
          self.class.encrypted_attributes.each do |attribute|
            errors.add(attribute.to_sym, "can't be modified because it is encrypted") if changed_attributes.include?(attribute)
          end
        end
    end
  end
end
