## Rails 5.1.0 (April 27, 2017) ##

*   The original string assigned to a model attribute is no longer incorrectly
    frozen.

    Fixes #24185, #28718.

    *Matthew Draper*

*   Avoid converting integer as a string into float.

    *namusyaka*

*   Remove deprecated behavior that halts callbacks when the return is false.

    *Rafael Mendonça França*

*   Remove unused `ActiveModel::TestCase` class.

    *Yuji Yaginuma*

*   Moved DecimalWithoutScale, Text, and UnsignedInteger from Active Model to Active Record

    *Iain Beeston*

*   Allow indifferent access in `ActiveModel::Errors`.

    `#include?`, `#has_key?`, `#key?`, `#delete` and `#full_messages_for`.

    *Kenichi Kamiya*

*   Removed deprecated `:tokenizer` in the length validator.

    *Rafael Mendonça França*

*   Removed deprecated methods in `ActiveModel::Errors`.

    `#get`, `#set`, `[]=`, `add_on_empty` and `add_on_blank`.

    *Rafael Mendonça França*


Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/activemodel/CHANGELOG.md) for previous changes.
