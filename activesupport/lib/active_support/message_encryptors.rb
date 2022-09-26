# frozen_string_literal: true

require "active_support/messages/rotation_coordinator"

module ActiveSupport
  class MessageEncryptors < Messages::RotationCoordinator
    ##
    # :method: initialize
    # :call-seq: initialize(&secret_generator)
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
    # :call-seq: rotate(**options)
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

    private
      def build(salt, secret_generator:, secret_generator_options:, **options)
        secret_length = MessageEncryptor.key_len(*options[:cipher])
        secret = secret_generator.call(salt, secret_length: secret_length, **secret_generator_options)
        MessageEncryptor.new(*Array(secret), **options)
      end
  end
end
