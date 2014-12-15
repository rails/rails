*   Deprecate returning `false` as a way to halt callback chains.

    Returning `false` in a callback will display a deprecation warning
    explaining that the preferred method to halt a callback chain is to
    explicitly `throw(:abort)`.

    *claudiob*

*   Changes arguments and default value of CallbackChain's :terminator option

    Chains of callbacks defined without an explicit `:terminator` option will
    now be halted as soon as a `before_` callback throws `:abort`.

    Chains of callbacks defined with a `:terminator` option will maintain their
    existing behavior of halting as soon as a `before_` callback matches the
    terminator's expectation. For instance, ActiveModel's callbacks will still
    halt the chain when a `before_` callback returns `false`.

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
