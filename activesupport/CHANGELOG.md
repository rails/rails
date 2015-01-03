*   Change the way in which callback chains can be halted.

    The preferred method to halt a callback chain from now on is to explicitly
    `throw(:abort)`.
    In the past, returning `false` in an ActiveSupport callback had the side
    effect of halting the callback chain. This is not recommended anymore and,
    depending on the value of
    `Callbacks::CallbackChain.halt_and_display_warning_on_return_false`, will
    either not work at all or display a deprecation warning.


*   Add Callbacks::CallbackChain.halt_and_display_warning_on_return_false

    Setting `Callbacks::CallbackChain.halt_and_display_warning_on_return_false`
    to true will let an app support the deprecated way of halting callback
    chains by returning `false`.

    Setting the value to false will tell the app to ignore any `false` value
    returned by callbacks, and only halt the chain upon `throw(:abort)`.

    The value can also be set with the Rails configuration option
    `config.active_support.halt_callback_chains_on_return_false`.

    When the configuration option is missing, its value is `true`, so older apps
    ported to Rails 5.0 will not break (but display a deprecation warning).
    For new Rails 5.0 apps, its value is set to `false` in an initializer, so
    these apps will support the new behavior by default.

    *claudiob*

*   Changes arguments and default value of CallbackChain's :terminator option

    Chains of callbacks defined without an explicit `:terminator` option will
    now be halted as soon as a `before_` callback throws `:abort`.

    Chains of callbacks defined with a `:terminator` option will maintain their
    existing behavior of halting as soon as a `before_` callback matches the
    terminator's expectation.

    *claudiob*

*   Deprecate `MissingSourceFile` in favor of `LoadError`.

    `MissingSourceFile` was just an alias to `LoadError` and was not being
    raised inside the framework.

    *Rafael Mendonça França*

*   Add support for error dispatcher classes in `ActiveSupport::Rescuable`.
    Now it acts closer to Ruby's rescue.

        class BaseController < ApplicationController
          module ErrorDispatcher
            def self.===(other)
              Exception === other && other.respond_to?(:status)
            end
          end

          rescue_from ErrorDispatcher do |error|
            render status: error.status, json: { error: error.to_s }
          end
        end

    *Genadi Samokovarov*

*   Add `#verified` and `#valid_message?` methods to `ActiveSupport::MessageVerifier`

    Previously, the only way to decode a message with `ActiveSupport::MessageVerifier`
    was to use `#verify`, which would raise an exception on invalid messages. Now
    `#verified` can also be used, which returns `nil` on messages that cannot be
    decoded.

    Previously, there was no way to check if a message's format was valid without
    attempting to decode it. `#valid_message?` is a boolean convenience method that
    checks whether the message is valid without actually decoding it.

    *Logan Leger*

Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/activesupport/CHANGELOG.md) for previous changes.
