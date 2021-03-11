**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Active Record Encryption
========================

This guide covers encrypting your database information using Active Record.

After reading this guide you will know:

* How to set up database encryption with Active Record.
* How to migrate unencrypted data
* How to make different encryption schemes coexist
* How to use the API
* How to configure the library and how to extend it

--------------------------------------------------------------------------------

Active Record supports application-level encryption. It works by declaring which attributes should be encrypted and seamlessly encrypting and decrypting them when necessary. The encryption layer is placed between the database and the application. The application will access unencrypted data but the database will store it encrypted.

## Basic usage

### Setup

First, you need to add some keys to your [rails credentials](/security.html#custom-credentials). Run `bin/rails db:encryption:init` to generate a random key set:

```bash
$ bin/rails db:encryption:init
Add this entry to the credentials of the target environment:

active_record.encryption:
  master_key: EGY8WhulUOXixybod7ZWwMIL68R9o5kC
  deterministic_key: aPA5XyALhf75NNnMzaspW7akTfZp0lPY
  key_derivation_salt: xEY0dt6TZcAMg52K7O84wYzkjvbA62Hz
```

NOTE: These generated keys and salt are 32 bytes length. If you generate these yourself, the minimum lengths you should use are 12 bytes for the master key (this will be used to derive the AES 32 bytes key) and 20 bytes for the salt.

### Declaration of encrypted attributes

Encryptable attributes are defined at the model level. These are regular Active Record attributes backed by a column with the same name. 

```ruby
class Article < ApplicationRecord
  encrypts :title
end
````

The library will transparently encrypt these attributes before saving them into the database, and will decrypt them when retrieving their values:

```ruby
article = Article.create title: "Encrypt it all!"
article.title # => "Encrypt it all"
```

But, under the hood, the executed SQL would look like this:

```sql
INSERT INTO `articles` (`title`) VALUES ('{\"p\":\"n7J0/ol+a7DRMeaE\",\"h\":{\"iv\":\"DXZMDWUKfp3bg/Yu\",\"at\":\"X1/YjMHbHD4talgF9dt61A==\"}}')
```

Encryption takes additional space in the column. You can estimate the worst-case overload in around 250 bytes when the built-in envelope encryption key provider is used. For medium and large text columns this overload is negligible, but for `string` columns of 255 bytes, you should increase their limit accordingly (510 is recommended).

NOTE: The reason for the additional space is that values are encoded in Base 64 and, also, that additional metadata is stored with the encrypted values. 

### Deterministic and non-deterministic encryption

By default, Active Record Encryption uses a non-deterministic approach to encryption. This means that encrypting the same content with the same password twice will result in different ciphertexts. This is good for security, since it makes crypto-analysis of encrypted content much harder, but it makes querying the database impossible.

You can use the `deterministic:`  option to generate initialization vectors in a deterministic way, effectively enabling querying encrypted data.

```ruby
class Author < ApplicationRecord
  encrypts :email, deterministic: true
end

Author.find_by_email("some@email.com") # You can query the model normally
```

The recommendation is using the default (non deterministic) unless you need to query the data.

NOTE: In non-deterministic mode, encryption is done using AES-GCM with a 256-bits key and a random initialization vector. In deterministic mode, it uses AES-GCM too but the initialization vector is generated as a HMAC-SHA-256 digest of the key and contents to encrypt.

## Features

### Action Text

You can encrypt action text attributes by passing `encrypted: true` in their declaration.

```ruby
class Message < ApplicationRecord
  has_rich_text :content, encrypted: true
end
```

NOTE: Passing individual encryption options to action text attributes is not supported yet. It will use non-deterministic encryption with the global encryption options configured.

### Fixtures

You can get Rails fixtures encrypted automatically by adding this option to your `test.rb`:

```ruby
config.active_record.encryption.encrypt_fixtures = true
```

When enabled, all the encryptable attributes will be encrypted according to the encryption settings defined in the model.

### Supported types

`active_record.encryption` will serialize values using the underlying type before encrypting them, but *they must be serializable as strings*, as that will be the value that the library will encrypt. Structured types like `serialized` are supported out of the box.

If you need to support a custom type, the recommended way is using a [serialized attribute](https://api.rubyonrails.org/classes/ActiveRecord/AttributeMethods/Serialization/ClassMethods.html). The declaration of the serialized attribute should go **before** the encryption declaration: 

```ruby
# GOOD
class Article < ApplicationRecord
  serialize :title, Title 
  encrypts :title
end

# WRONG
class Article < ApplicationRecord
  encrypts :title
  serialize :title, Title 
end
```

### Ignoring case

You might need to ignore case when querying deterministically encrypted data. There are two options that can help you here.

You can use the option `:downcase`  when declaring the encrypted attribute. This will make that content is downcased before being encrypted.

```ruby
class Person
  encrypts :email_address, deterministic: true, downcase: true
end
```

When using `:downcase` the original case is lost. There might be cases where you need to preserve the original case when reading the value, but you need to ignore the case when querying. For those cases you can use the option `:ignore_case` which requires you to add a new column named `original_<column_name>` to store the content with the case unchanged:

```ruby
class Label
  encrypts :name, deterministic: true, ignore_case: true # the content with the original case will be stored in the column `original_name`
end
```

### Support for unencrypted data

To ease migrations of unencrypted data, the library includes the option `config.active_record.encryption.support_unencrypted_data`. When set to `true`:

* Trying to read encrypted attributes that are not encrypted will work normally, without raising any error
* Queries with deterministically-encrypted attributes will include the "clear text" version of them, to support finding both encrypted and unencrypted content. You need to set `config.active_record.encryption.extend_queries = true` to enable this.

**This options is meant to be used in transition periods** while clear data and encrypted data need to coexist. Their value is `false` by default, which is the recommended goal for any application: errors will be raised when working with unencrypted data.

### Support for previous encrypting schemes

Changing encryption properties of attributes can break existing data. For example, imagine you wan to make a "deterministic" attribute "not deterministic". If you just change the declaration in the model, reading existing ciphertexts will fail because they are different now.

To support these situations, you can use `:previous` to declare previous encryption schemes:

```ruby
class Article
  encrypts :title, deterministic: true, previous: { deterministic: false }
end
```
This declaration has 2 effects:

* When reading encrypted data, Active Record Encryption will try previous encryption schemes if the current scheme doesn't work.
* When querying deterministic data, it will add ciphertexts using previous schemes to the queries so that queries work seamlessly with data encrypted with different scheme. You need to set `config.active_record.encryption.extend_queries = true` to enable this.

### Filtering params named as encrypted columns

By default, encrypted columns are configured to be [automatically filtered in Rails logs](https://guides.rubyonrails.org/action_controller_overview.html#parameters-filtering). You can disable this behavior by adding this to your `application.rb`:

```ruby
config.active_record.encryption.add_to_filter_parameters = false
```
In case you want exclude specific columns from this automatic filtering, add them to `config.active_record.encryption.excluded_from_filter_parameters`.

## Key management

Key management strategies are implemented by key providers. You can configure key providers globally or on a per-attribute basis. 

### Built-in key providers

#### DerivedSecretKeyProvider

A key provider that will serve keys derived from the provided passwords using PBKDF2. 

```ruby
config.active_record.encryption.key_provider = ActiveRecord::Encryption::DerivedSecretKeyProvider.new(["some passwords", "to derive keys from. ", "These should be in", "credentials"])
```

NOTE: By default, `active_record.encryption` configures a `DerivedSecretKeyProvider` with the keys defined in `active_record.encryption.master_key`.

#### EnvelopeEncryptionKeyProvider

Implements a simple [envelope encryption](https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html#enveloping) strategy:

- It generates a random key for each data-encryption operation
- It stores the data-key with the data itself, encrypted with a master key defined in the credential `active_record.encryption.master_key`.

You can configure by adding this to your `application.rb`:

```ruby
config.active_record.encryption.key_provider = ActiveRecord::Encryption::EnvelopeEncryptionKeyProvider.new
```

As with other built-in key providers, you can provide a list of master keys in `active_record.encryption.master_key`, to implement key-rotation schemes.

### Custom key providers

For more advanced key-management schemes, you can configure a custom key provider in a initializer:

```ruby
ActiveRecord::Encryption.key_provider = MyKeyProvider.new
```

A key provider must implement this interface:

```ruby
class MyKeyProvider
  def encryption_key
  end

  def decryption_keys(encrypted_message)
  end
end
```

Both methods return `ActiveRecord::Encryption::Key` objects:

- `encryption_key` returns the key used for encrypting some content
- `decryption keys` returns a list of potential keys for decrypting a given message

A key can include arbitrary tags that will be stored unencrypted with the message. You can use `ActiveRecord::Encryption::Message#headers` to examine those values when decrypting.

### Model-specific key providers

You can configure a key provider on a per-class basis with the `:key_provider` option:

```ruby
class Article < ApplicationRecord
  encrypts :summary, key_provider: ArticleKeyProvider.new
end
```

### Model-specific keys

You can configure a given key on a per-class basis with the `:key` option:

```ruby
class Article < ApplicationRecord
  encrypts :summary, key: "some secret key for article summaries"
end
```

The key will be used internally to derive the key used to encrypt and decrypt the data.

### Rotating keys

`active_record.encryption` can work with lists of keys, to support implementing key-rotation schemes:

- The **first key** will be used for encrypting new content.
- All the keys will be tried when decrypting content, until one works.

```yml
active_record.encryption:
    master_key:
        - bc17e7b413fd4720716a7633027f8cc4 # Active, encrypts new content
        - a1cc4d7b9f420e40a337b9e68c5ecec6 # Previous keys can still decrypt existing content
    key_derivation_salt: a3226b97b3b2f8372d1fc6d497a0c0d3
```

This enables workflows where you keep a short list of keys, by adding new keys, re-encrypting content and deleting old keys.

This works consistently across the built-in key providers. Also, when using a deterministic encryption strategy, you can set a list of keys in `active_record.encryption.deterministic_key`.

```yaml
active_record.encryption:
  deterministic_key:
    - dd9e4ffef6eced8317667d70df7c75eb # Active, encrypts new content
    - 6940371df37f040e0e8a12948bb31cda # Previous keys can still decrypt existing content
```

NOTE: Active Record Encryption doesn't provide automatic management of key rotation processes yet. All the pieces are there, but this hasn't been implemented yet. 

### Storing key references

There is a setting `active_record.encryption.store_key_references` you can use to make `active_record.encryption` store a reference to the encryption key in the encrypted message itself. 

```ruby
config.active_record.encryption.store_key_references = true
```

This makes for a more performant decryption since, instead of trying lists of keys, the system can now locate keys directly. The price to pay is storage: encrypted data will be a bit bigger in size.

## API

### Basic API

ActiveRecord encryption is meant to be used declaratively, but it presents an API for advanced usage scenarios.

#### Encrypt and decrypt

```ruby
article.encrypt # encrypt or re-encrypt all the encryptable attributes
article.decrypt # decrypt all the encryptable attributes
```

#### Read ciphertext

```ruby
article.ciphertext_for(:title)
```

#### Check if attribute is encrypted or not

```ruby
article.encrypted_attribute?(:title)
```

## Configuration

### Configuration options

You can configure Active Record Encryption options by setting them in your `application.rb` (most common scenario) or in a specific environment config file `config/environments/<env name>.rb` if you want to set them on a per-environment basis.

All the config options are namespaced in `active_record.encryption.config`. For example:

```ruby
config.active_record.encryption.key_provider = ActiveRecord::Encryption::EnvelopeEncryptionKeyProvider.new
config.active_record.encryption.store_key_references = true
config.active_record.encryption.extend_queries = true
```
The available config options are:

| Key                                                          | Value                                                        |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| `support_unencrypted_data`                                   | When true, unencrypted data can be read normally. When false, it will raise. Default: false. |
| `extend_queries` | When true, queries referencing deterministically encrypted attributes will be modified to include additional values if needed. Those additional values will be the clean version of the value, when `support_unencrypted_data` is true) and values encrypted with previous encryption schemes if any (as provided with the `previous:` option). Default: false (experimental). |
| `encrypt_fixtures`                                           | When true, encryptable attributes in fixtures will be automatically encrypted when those are loaded. Default: false. |
| `store_key_references`                                       | When true, a reference to the encryption key is stored in the headers of the encrypted message. This makes for a faster decryption when multiple keys are in use. Default: false. |
| `add_to_filter_parameters`                                   | When true, encrypted attribute names are added automatically to the [list of filtered params](https://guides.rubyonrails.org/configuring.html#rails-general-configuration) that won't be shown in logs. Default: true. |
| `excluded_from_filter_parameters`                            | You can configure a list of params that won't be filtered out when `add_to_filter_parameters` is true. Default: []. |
| `validate_column_size`                                        | Adds a validation based on the column size. This is recommended to prevent storing huge values using highly compressible payloads. Default: true. |
| `master_key`                                                 | The key or lists of keys that is used to derive root data-encryption keys. They way they are used depends on the key provider configured. It's preferred to configure it via a credential `active_record_encryption.master_key`. |
| `deterministic_key`                                          | The key or list of keys used for deterministic encryption. It's preferred to configure it via a credential `active_record_encryption.deterministic_key`. |
| `key_derivation_salt`                                        | The salt used when deriving keys. It's preferred to configure it via a credential `active_record_encryption.key_derivation_salt`. |

NOTE: It's recommende to use Rails built-in credentials support to store keys. If you prefer to set them manually via config properties, make sure you don't commit them with your code (e.g: use environment variables).

### Encryption contexts

An encryption context defines the encryption components that are used in a given moment. There is a default encryption context based on your global configuration, but you can configure a custom context for a given attribute or when running a specific block of code.

NOTE: Encryption contexts are a flexible but advanced configuration mechanism. Most users should not have to care about them.

The main components of encryption contexts are:

* `encryptor`: exposes the internal API for encrypting and decrypting data.  It interacts with a `key_provider` to build encrypted messages and deal with their serialization. The encryption/decryption itself is done by the `cipher` and the serialization by `message_serializer`.
* `cipher` the encryption algorithm itself (Aes 256 GCM)
* `key_provider` serves encryption and decryption keys.
* `message_serializer`: serializes and deserializes encrypted payloads (`Message`).

NOTE: If you decide to build your own `message_serializer`, It's important to use safe mechanisms that can't deserialize arbitrary objects. A common supported scenario is encrypting existing unencrypted data. An attacker can leverage this to enter a tampered payload before encryption takes place and perform RCE attacks. This means custom serializers should avoid `Marshal`, `YAML.load` (use `YAML.safe_load`  instead) or `JSON.load` (use `JSON.parse` instead).

#### Global encryption context

The global encryption context is the one used by default and is configured as other configuration properties in your `application.rb` or environment config files.

```ruby
config.active_record.encryption.key_provider = ActiveRecord::Encryption::EnvelopeEncryptionKeyProvider.new
config.active_record_encryption.encryptor = MyEncryptor.new
```

#### Per-attribute encryption contexts

You can override encryption context params by passing them in the attribute declaration:

```ruby
class Attribute
  encrypts :title, encryptor: MyAttributeEncryptor.new
end
```

#### Encryption context when running a block of code

You can use `ActiveRecord::Encryption.with_encryption_context` to set an encryption context for a given block of code:

```ruby
ActiveRecord::Encryption.with_encryption_context(encryptor: ActiveRecord::Encryption::NullEncryptor.new) do
  ...
end
```

#### Built-in encryption contexts

#####  Disable encryption

You can run code without encryption:

```ruby
ActiveRecord::Encryption.without_encryption do
   ...
end
```
This means that reading encrypted text will return the ciphertext and saved content will be stored unencrypted.

#####  Protect encrypted data

You can run code without encryption but preventing overwriting encrypted content:

```ruby
ActiveRecord::Encryption.protecting_encrypted_data do
   ...
end
```
This can be handy if you want to protect encrypted data while still letting someone run arbitrary code against it (e.g: in a Rails console).