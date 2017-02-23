## Rails 5.1.0.beta1 (February 23, 2017) ##

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
