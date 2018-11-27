## Rails 5.1.6.1 (November 27, 2018) ##

*   No changes.


## Rails 5.1.6 (March 29, 2018) ##

*   No changes.


## Rails 5.1.5 (February 14, 2018) ##

*   Fix to working before/after validation callbacks on multiple contexts.

    *Yoshiyuki Hirano*

## Rails 5.1.4 (September 07, 2017) ##

*   No changes.


## Rails 5.1.4.rc1 (August 24, 2017) ##

*   No changes.


## Rails 5.1.3 (August 03, 2017) ##

*   No changes.


## Rails 5.1.3.rc3 (July 31, 2017) ##

*   No changes.


## Rails 5.1.3.rc2 (July 25, 2017) ##

*   No changes.


## Rails 5.1.3.rc1 (July 19, 2017) ##

*   No changes.


## Rails 5.1.2 (June 26, 2017) ##

*   Fix regression in numericality validator when comparing Decimal and Float input 
    values with more scale than the schema.

    *Bradley Priest*


## Rails 5.1.1 (May 12, 2017) ##

*   No changes.


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
