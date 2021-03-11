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
        # === Options
        #
        # * <tt>:key_provider</tt> - Configure a +KeyProvider+ for serving the keys to encrypt and
        #   decrypt this attribute. If not provided, it will default to +ActiveRecord::Encryption.key_provider+.
        # * <tt>:key</tt> - A password to derive the key from. It's a shorthand for a +:key_provider+ that
        #   serves derivated keys. Both options can't be used at the same time.
        # * <tt>:key_provider</tt> - Set a +:key_provider+ to provide encryption and decryption keys. If not
        #   provided, it will default to the key provider set with `config.key_provider`.
        # * <tt>:deterministic</tt> - By default, encryption is not deterministic. It will use a random
        #   initialization vector for each encryption operation. This means that encrypting the same content
        #   with the same key twice will generate different ciphertexts. When set to +true+, it will generate the
        #   initialization vector based on the encrypted content. This means that the same content will generate
        #   the same ciphertexts. This enables querying encrypted text with Active Record.
        # * <tt>:downcase</tt> - When true, it converts the encrypted content to downcase automatically. This allows to
        #   effectively ignore case when querying data. Notice that the case is lost. Use +:ignore_case+ if you are interested
        #   in preserving it.
        # * <tt>:ignore_case</tt> - When true, it behaves like +:downcase+ but, it also preserves the original case in a specially
        #   designated column +original_<name>+. When reading the encrypted content, the version with the original case is
        #   server. But you can still execute queries that will ignore the case. This option can only be used when +:deterministic+
        #   is true.
        # * <tt>:context_properties</tt> - Additional properties that will override +Context+ settings when this attribute is
        #   encrypted and decrypted. E.g: +encryptor:+, +cipher:+, +message_serializer:+, etc.
        # * <tt>:previous</tt> - List of previous encryption schemes. When provided, they will be used in order when trying to read
        #   the attribute. Each entry of the list can contain the properties supported by #encrypts. Also, when deterministic
        #   encryption is used, they will be used to generate additional ciphertexts to check in the queries.
        def encrypts(*names, key_provider: nil, key: nil, deterministic: false, downcase: false, ignore_case: false, previous: [], **context_properties)
          self.encrypted_attributes ||= Set.new # not using :default because the instance would be shared across classes

          if table_exists?
            names.each do |name|
              encrypt_attribute name, key_provider: key_provider, key: key, deterministic: deterministic, downcase: downcase,
                                ignore_case: ignore_case, subtype: type_for_attribute(name), previous: previous, **context_properties
            end
          end
        end

        # Returns the list of deterministic encryptable attributes in the model class.
        def deterministic_encrypted_attributes
          @deterministic_encrypted_attributes ||= encrypted_attributes&.find_all do |attribute_name|
            type_for_attribute(attribute_name).deterministic?
          end
        end

        # Given a attribute name, it returns the name of the source attribute when it's a preserved one
        def source_attribute_from_preserved_attribute(attribute_name)
          attribute_name.to_s.sub(ORIGINAL_ATTRIBUTE_PREFIX, "") if /^#{ORIGINAL_ATTRIBUTE_PREFIX}/.match?(attribute_name)
        end

        private
          def encrypt_attribute(name, key_provider: nil, key: nil, deterministic: false, downcase: false,
                                ignore_case: false, subtype: ActiveModel::Type::String.new, previous: [], **context_properties)
            raise Errors::Configuration, ":ignore_case can only be used with deterministic encryption" if ignore_case && !deterministic
            raise Errors::Configuration, ":key_provider and :key can't be used simultaneously" if key_provider && key

            encrypted_attributes << name.to_sym

            key_provider = build_key_provider(key_provider: key_provider, key: key, deterministic: deterministic)

            attribute name, :encrypted, key_provider: key_provider, downcase: downcase || ignore_case, deterministic: deterministic,
                      subtype: subtype, previous_types: build_previous_types(previous, subtype), **context_properties

            preserve_original_encrypted(name) if ignore_case
            validate_column_size(name) if ActiveRecord::Encryption.config.validate_column_size
            ActiveRecord::Encryption.encrypted_attribute_was_declared(self, name)
          end

          def build_previous_types(previous_config_list, type)
            previous_config_list = [previous_config_list] unless previous_config_list.is_a?(Array)
            previous_config_list.collect do |previous_config|
              key_provider = build_key_provider(**previous_config.slice(:key_provider, :key, :deterministic))
              context_properties = previous_config.slice(*ActiveRecord::Encryption::Context::PROPERTIES.without(:key_provider))
              ActiveRecord::Encryption::EncryptedAttributeType.new \
                  key_provider: key_provider, downcase: previous_config[:downcase] || previous_config[:ignore_case],
                  deterministic: previous_config[:deterministic], subtype: type, **context_properties
            end
          end

          def build_key_provider(key_provider: nil, key: nil, deterministic: false)
            return DerivedSecretKeyProvider.new(key) if key.present?
            return key_provider if key_provider

            if deterministic && (deterministic_key = ActiveRecord::Encryption.config.deterministic_key)
              DerivedSecretKeyProvider.new(deterministic_key)
            end
          end

          def preserve_original_encrypted(name)
            original_attribute_name = "#{ORIGINAL_ATTRIBUTE_PREFIX}#{name}".to_sym

            if !ActiveRecord::Encryption.config.support_unencrypted_data && !column_names.include?(original_attribute_name.to_s)
              raise Errors::Configuration, "To use :ignore_case for '#{name}' you must create an additional column named '#{original_attribute_name}'"
            end

            encrypts original_attribute_name

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
          end

          def validate_column_size(attribute_name)
            if limit = connection.schema_cache.columns_hash(table_name)[attribute_name.to_s]&.limit
              validates_length_of attribute_name, maximum: limit
            end
          end
      end

      # Returns whether a given attribute is encrypted or not
      def encrypted_attribute?(attribute_name)
        ActiveRecord::Encryption.encryptor.encrypted? ciphertext_for(attribute_name)
      end

      # Returns the ciphertext for +attribute_name+
      def ciphertext_for(attribute_name)
        read_attribute_before_type_cast(attribute_name)
      end

      # Encrypts all the encryptable attributes and saves the model
      #
      # === Options
      #
      # * <tt>:skip_rich_texts</tt> - Configure if you want to ignore action text attributes
      #   when encrypting the record. It's false by default.
      #
      #   Encrypting action text requires performing additional queries to fetch the rich text
      #   records. This is a performance setting to avoid those queries when possible.
      def encrypt(skip_rich_texts: false)
        transaction do
          encrypt_attributes if has_encrypted_attributes?
          encrypt_rich_texts if !skip_rich_texts && has_encrypted_rich_texts?
        end
      end

      # Decrypts all the encryptable attributes and saves the model
      def decrypt
        transaction do
          decrypt_attributes if has_encrypted_attributes?
          decrypt_rich_texts if has_encrypted_rich_texts?
        end
      end

      private
        ORIGINAL_ATTRIBUTE_PREFIX = "original_"

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

        def has_encrypted_rich_texts?
          encryptable_rich_texts.present?
        end

        def build_encrypt_attribute_assignments
          Array(self.class.encrypted_attributes).index_with do |attribute_name|
            if source_attribute_name = self.class.source_attribute_from_preserved_attribute(attribute_name)
              self[source_attribute_name]
            else
              self[attribute_name]
            end
          end
        end

        def build_decrypt_attribute_assignments
          Array(self.class.encrypted_attributes).collect do |attribute_name|
            type = type_for_attribute(attribute_name)
            encrypted_value = ciphertext_for(attribute_name)
            new_value = type.deserialize(encrypted_value)
            [attribute_name, new_value]
          end.to_h
        end

        def encrypt_rich_texts
          encryptable_rich_texts.each(&:encrypt)
        end

        def decrypt_rich_texts
          encryptable_rich_texts.each(&:decrypt)
        end

        def encryptable_rich_texts
          @encryptable_rich_texts ||= self.class
                                          .reflect_on_all_associations(:has_one)
                                          .collect(&:name)
                                          .grep(/rich_text/)
                                          .collect { |attribute_name| send(attribute_name) }.compact
                                          .find_all { |record| record.class.name == "ActionText::EncryptedRichText" } # not using class check to avoid adding dependency
        end

        def cant_modify_encrypted_attributes_when_frozen
          self.class&.encrypted_attributes.each do |attribute|
            errors.add(attribute.to_sym, "can't be modified because it is encrypted") if changed_attributes.include?(attribute)
          end
        end
    end
  end
end
