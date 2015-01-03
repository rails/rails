*   Remove deprecated `ActiveModel::Dirty#reset_#{attribute}` and
    `ActiveModel::Dirty#reset_changes`.

    *Rafael Mendonça França*

*   Change the way in which callback chains can be halted.

    The preferred method to halt a callback chain from now on is to explicitly
    `throw(:abort)`.
    In the past, returning `false` in an ActiveModel or ActiveModel::Validations
    `before_` callback had the side effect of halting the callback chain.
    This is not recommended anymore and, depending on the value of the
    `config.active_support.halt_callback_chains_on_return_false` option, will
    either not work at all or display a deprecation warning.


Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/activemodel/CHANGELOG.md) for previous changes.
