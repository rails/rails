# frozen_string_literal: true

require "active_support/messages/rotation_coordinator"

module ActiveSupport
  class MessageEncryptors < Messages::RotationCoordinator
    ##
    # :attr_accessor: transitional
    #
    # If true, the first two rotation option sets are swapped when building
    # message encryptors. For example, with the following configuration, message
    # encryptors will encrypt messages using <tt>serializer: Marshal, url_safe: true</tt>,
    # and will able to decrypt messages that were encrypted using any of the
    # three option sets:
    #
    #   encryptors = ActiveSupport::MessageEncryptors.new { ... }
    #   encryptors.rotate(serializer: JSON, url_safe: true)
    #   encryptors.rotate(serializer: Marshal, url_safe: true)
    #   encryptors.rotate(serializer: Marshal, url_safe: false)
    #   encryptors.transitional = true
    #
    # This can be useful when performing a rolling deploy of an application,
    # wherein servers that have not yet been updated must still be able to
    # decrypt messages from updated servers. In such a scenario, first perform a
    # rolling deploy with the new rotation (e.g. <tt>serializer: JSON, url_safe: true</tt>)
    # as the first rotation and <tt>transitional = true</tt>. Then, after all
    # servers have been updated, perform a second rolling deploy with
    # <tt>transitional = false</tt>.

    ##
    # :singleton-method: new
    # :call-seq: new(&secret_generator)
    #
    # Initializes a new instance. +secret_generator+ must accept a salt and a
    # +secret_length+ kwarg, and return a suitable secret (string) or secrets
    # (array of strings). +secret_generator+ may also accept other arbitrary
    # kwargs. If #rotate is called with any options matching those kwargs, those
    # options will be passed to +secret_generator+ instead of to the message
    # encryptor.
    #
    #   encryptors = ActiveSupport::MessageEncryptors.new do |salt, secret_length:, base:|
    #     MySecretGenerator.new(base).generate(salt, secret_length)
    #   end
    #
    #   encryptors.rotate(base: "...")

    ##
    # :method: []
    # :call-seq: [](salt)
    #
    # Returns a MessageEncryptor configured with a secret derived from the
    # given +salt+, and options from #rotate. MessageEncryptor instances will
    # be memoized, so the same +salt+ will return the same instance.

    ##
    # :method: []=
    # :call-seq: []=(salt, encryptor)
    #
    # Overrides a MessageEncryptor instance associated with a given +salt+.

    ##
    # :method: rotate
    # :call-seq:
    #   rotate(**options)
    #   rotate(&block)
    #
    # Adds +options+ to the list of option sets. Messages will be encrypted
    # using the first set in the list. When decrypting, however, each set will
    # be tried, in order, until one succeeds.
    #
    # Notably, the +:secret_generator+ option can specify a different secret
    # generator than the one initially specified. The secret generator must
    # respond to +call+, accept a salt and a +secret_length+ kwarg, and return
    # a suitable secret (string) or secrets (array of strings). The secret
    # generator may also accept other arbitrary kwargs.
    #
    # If any options match the kwargs of the operative secret generator, those
    # options will be passed to the secret generator instead of to the message
    # encryptor.
    #
    # For fine-grained per-salt rotations, a block form is supported. The block
    # will receive the salt, and should return an appropriate options Hash. The
    # block may also return +nil+ to indicate that the rotation does not apply
    # to the given salt. For example:
    #
    #   encryptors = ActiveSupport::MessageEncryptors.new { ... }
    #
    #   encryptors.rotate do |salt|
    #     case salt
    #     when :foo
    #       { serializer: JSON, url_safe: true }
    #     when :bar
    #       { serializer: Marshal, url_safe: true }
    #     end
    #   end
    #
    #   encryptors.rotate(serializer: Marshal, url_safe: false)
    #
    #   # Uses `serializer: JSON, url_safe: true`.
    #   # Falls back to `serializer: Marshal, url_safe: false`.
    #   encryptors[:foo]
    #
    #   # Uses `serializer: Marshal, url_safe: true`.
    #   # Falls back to `serializer: Marshal, url_safe: false`.
    #   encryptors[:bar]
    #
    #   # Uses `serializer: Marshal, url_safe: false`.
    #   encryptors[:baz]

    ##
    # :method: rotate_defaults
    # :call-seq: rotate_defaults
    #
    # Invokes #rotate with the default options.

    ##
    # :method: clear_rotations
    # :call-seq: clear_rotations
    #
    # Clears the list of option sets.

    ##
    # :method: on_rotation
    # :call-seq: on_rotation(&callback)
    #
    # Sets a callback to invoke when a message is decrypted using an option set
    # other than the first.
    #
    # For example, this callback could log each time it is called, and thus
    # indicate whether old option sets are still in use or can be removed from
    # rotation.

    ##
    private
      def build(salt, secret_generator:, secret_generator_options:, **options)
        secret_length = MessageEncryptor.key_len(*options[:cipher])
        secret = secret_generator.call(salt, secret_length: secret_length, **secret_generator_options)
        MessageEncryptor.new(*Array(secret), **options)
      end
  end
end
