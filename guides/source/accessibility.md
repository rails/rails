**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON
<https://guides.rubyonrails.org>.**

Accessibility
=============

This guide covers how to build accessible web applications with Rails.
Accessibility (often abbreviated as "a11y") means making applications usable by
everyone, regardless of their abilities or how they interact with a computer.

After reading this guide, you will know:

* Why accessibility matters.
* What assistive technologies are and how people use them to navigate the web.
* Why semantic HTML is the foundation of accessibility.
* When and how to use ARIA to fill the gaps that native HTML leaves.
* How to structure pages with language, titles, landmarks, skip links, and
  headings.
* How to build accessible links, buttons, multimedia, tables, and forms.
* How to use native HTML for common patterns like disclosures, dialogs,
  popovers, and tooltips.
* How to write CSS that keeps focus, target size, contrast, zoom, and user
  preferences in check.
* How to manage focus, announce updates, signal in-flight submissions, and
  confirm destructive actions in apps driven by Turbo.
* How to test for accessibility with automated tools and with the same input
  methods real users rely on.

--------------------------------------------------------------------------------

Why Accessibility Matters
-------------------------

Accessibility means building applications that work for people regardless of how
they use a computer: keyboard only, screen reader, magnifier, voice control,
switch device, or any combination.

Most of the web does not. The [WebAIM Million][webaim-million] report audits the
top one million home pages every year and consistently finds detectable WCAG
failures on around 95% of them. The [World Health Organization
estimates][who-disability] that roughly one in six people lives with a
significant disability, so the gap between that audience and the inaccessible
state of the web is large.

This guide is a practical reference for closing that gap in a Rails application.
It covers the specific mistakes that lock out part of an audience, and it shows
where Rails helpers and modern HTML already do the work. Building accessibility
in from the start costs little; retrofitting it later is the expensive option.

[webaim-million]: https://webaim.org/projects/million/
[who-disability]: https://www.who.int/news-room/fact-sheets/detail/disability-and-health

### The Web Content Accessibility Guidelines (WCAG)

The [Web Content Accessibility Guidelines
(WCAG)](https://www.w3.org/WAI/standards-guidelines/wcag/) are the
internationally recognized standard for web accessibility. They are organized
around [four
principles](https://www.w3.org/WAI/fundamentals/accessibility-principles/),
often summarized with the mnemonic **POUR**:

* **Perceivable**: Information and user interface components must be presentable
  to users in ways they can perceive (text alternatives for images, captions for
  video, sufficient color contrast).
* **Operable**: User interface components and navigation must be operable
  (keyboard accessible, enough time to interact, no content that causes
  seizures).
* **Understandable**: Information and the operation of user interface must be
  understandable (readable text, predictable behavior, help with errors).
* **Robust**: Content must be robust enough that it can be interpreted reliably
  by a wide variety of user agents, including assistive technologies.

The widely accepted baseline for web applications is conformance with [WCAG 2.2
Level AA](https://www.w3.org/TR/WCAG22/). It was also adopted as an ISO standard
([ISO/IEC 40500:2025](https://www.iso.org/standard/91029.html)) in October 2025,
consolidating its role as the de facto reference.

This guide is not an exhaustive walkthrough of every WCAG success criterion.
Many of them are covered directly, some are cited in passing where they come up,
and a few fall outside the scope of a typical Rails application. Treat the
criteria referenced throughout as pointers into the specification rather than a
checklist, and consult [WCAG 2.2](https://www.w3.org/TR/WCAG22/) when a project
needs formal conformance.

### Legal Requirements

Web accessibility is also a legal requirement in many jurisdictions, typically
through regional standards that incorporate WCAG. In the **European Union**, the
[European Accessibility Act][eaa] applies to a defined range of consumer
products and services, and compliance is demonstrated against the harmonized [EN
301 549][en-301] standard. In the **United States**, the [Americans with
Disabilities Act][ada] applies to government and private websites, and [Section
508][s508] of the Rehabilitation Act sets WCAG-based requirements for federal
agencies.

Many other countries maintain similar frameworks. The W3C Web Accessibility
Initiative publishes a [comprehensive list of accessibility policies by
country](https://www.w3.org/WAI/policies/), which is the right starting point
for any specific jurisdiction.

[eaa]: https://commission.europa.eu/strategy-and-policy/policies/justice-and-fundamental-rights/disability/european-accessibility-act-eaa_en
[en-301]: https://digital-strategy.ec.europa.eu/en/policies/web-accessibility-directive-standards-and-harmonisation
[ada]: https://www.ada.gov/
[s508]: https://www.access-board.gov/ict/

How People Use the Web
----------------------

Before writing any code, it helps to understand how different people interact
with web applications. Not everyone uses a mouse, a monitor, or a touchscreen in
the same way, and some do not use them at all.

### Assistive Technologies

An **assistive technology** is any tool that helps a person interact with a
computer. The categories below are the ones that matter most when building for
the web:

* **Screen readers:** Programs that convert screen content into speech or
  braille output. A blind or visually impaired user listens to a synthetic voice
  that announces text, headings, links, buttons, and form controls as they
  navigate. Screen readers do not "see" the page; they read the underlying HTML
  structure. Popular screen readers include [NVDA](https://www.nvaccess.org/)
  (Windows), [VoiceOver][vo-mac-guide] (built into macOS),
  [Orca](https://orca.gnome.org/) (Linux), [VoiceOver][vo-ios-guide] (built into
  iOS and iPadOS), and [TalkBack][talkback-guide] (built into Android).

* **Screen magnifiers:** Programs that enlarge portions of the screen for people
  with low vision. Users see only a small area of the page at a time and
  navigate by panning around. Good structure, consistent layouts, and clear
  focus indicators help magnifier users orient themselves. macOS and iOS/iPadOS
  include Zoom, Windows includes Magnifier, and Android includes Magnification.

* **Voice control:** Software that allows users to speak commands instead of
  using a keyboard or mouse. A user might say "click Submit" or "click Email" to
  interact with buttons and form fields. For this to work, every interactive
  element needs an accessible name, ideally its visible text. A control with no
  name at all, like an unlabeled icon button, gives voice control nothing to
  match. Voice control is built into all major platforms: Voice Control on
  macOS/iOS, Voice Access on Windows and Android.

* **Switch devices:** Physical devices used by people with significant motor
  limitations. A switch device might be a single button or a sip-and-puff
  device. The OS scans the interface and highlights items in turn, and the user
  presses the switch to activate the current target. Keyboard accessibility and
  a clean focus order are essential for switch users. Switch Control is built
  into macOS, iOS, and iPadOS, and Switch Access is built into Android.

* **Hands-free pointing:** Head and eye trackers let people with significant
  motor limitations control a cursor without a mouse. Activation usually relies
  on dwell-to-click, where holding the pointer still over a target for a moment
  triggers a click, so adequate target size and pointer-friendly interactions
  matter most for these users. macOS includes Head Pointer, iOS and iPadOS
  include Eye Tracking, and Windows offers Eye Control with compatible hardware.

[vo-mac-guide]: https://support.apple.com/guide/voiceover/welcome/mac
[vo-ios-guide]: https://support.apple.com/guide/iphone/turn-on-and-practice-voiceover-iph3e2e415f/ios
[talkback-guide]: https://support.google.com/accessibility/android/answer/6283677

Everything in an application (every link, button, form field, dialog, and menu)
must be reachable and operable with the **keyboard alone**. This is the
foundation that all of these technologies depend on. Screen readers, voice
control, and switch devices all ultimately rely on the same underlying keyboard
and focus model.

### How Screen Readers Work

Screen readers are the assistive technology most affected by how HTML is
written, so they deserve a closer look.

A screen reader does **not** see the page the way a sighted user does. Instead,
it reads the [**accessibility tree**][accessibility-tree], a structured
representation of the page that the browser builds from the HTML. That tree is
to screen readers what the visual layout is to sighted users.

[accessibility-tree]: https://developer.mozilla.org/en-US/docs/Glossary/Accessibility_tree

Content is read in the **order it appears in the HTML source**, from top to
bottom. If CSS visually reorders elements (with `order`, `position`, or `grid`
placement), screen reader users will hear the content in a different order than
sighted users see it. This disconnect can make pages confusing or unusable
([WCAG 1.3.2 Meaningful Sequence][wcag-meaningful-sequence]). The HTML source
order is the truth for assistive technologies.

[wcag-meaningful-sequence]: https://www.w3.org/WAI/WCAG22/Understanding/meaningful-sequence.html

When the HTML is **semantic**, meaning the correct elements are used for their
intended purpose, the browser creates a rich accessibility tree. It knows that a
`<button>` is a button, a `<nav>` is navigation, an `<h2>` is a second-level
heading. The screen reader can then announce these elements accurately and let
the user navigate between them efficiently.

Without that semantic structure, when the page is built from `<div>` and
`<span>` elements alone, the accessibility tree is flat and meaningless, like a
wall of unstyled text. The screen reader cannot distinguish a heading from a
paragraph, or a button from plain text.

Everything above applies to every screen reader, on every platform: they all
traverse the same accessibility tree. What changes between devices is how the
user drives the screen reader. On desktop, navigation is driven by the keyboard.
On mobile, by touch gestures.

#### On Desktop

Screen reader users **do not** navigate pages by pressing Tab from top to
bottom. The Tab key only moves between things a user can click or type into,
known as **interactive elements**. On the web these are links, buttons, and form
controls. Everything else (headings, paragraphs, images, lists, tables, and
ordinary text) is not a Tab stop and is skipped entirely. Pressing it repeatedly
on a typical article page jumps between navigation links and form fields while
the article body itself stays out of reach. A screen reader user who only had
Tab available would never read the article.

To make the rest of the page reachable, the screen reader **intercepts keyboard
input** and reassigns keys to serve as navigation commands. When one is running,
pressing `H` does not type the letter "h"; it jumps to the next heading.
Pressing `D` jumps to the next landmark region. The reader takes over the
keyboard to create its own navigation system on top of the browser.

This approach works as long as the user is reading, but it stops working the
moment they reach a form field, where every letter would still be intercepted as
a navigation command instead of being typed. Screen readers reconcile this by
operating in two distinct modes, **browse** and **focus**, and swapping between
them automatically depending on whether the user is reading or interacting with
a control.

##### Browse Mode

Browse mode is the default and is what the user stays in while reading. The
screen reader intercepts every keystroke and uses it as a navigation command, so
the keyboard effectively belongs to the tool rather than the browser.

This setup exists to enable **quick navigation** through the page. A sighted
user scans a page visually to spot the main article, a sidebar, navigation
links, or a search form, usually in a second or two. Browse mode gives a screen
reader user the same ability in audio: a single keystroke jumps to the next
heading on the page and announces it; another keystroke jumps to the next one;
another to the next landmark region; another to the next link. The user can
survey the page structure this way without listening to the paragraphs in
between, then stop at whatever they want to read in full.

The categories readers jump through are consistent everywhere: headings (and
specific heading levels), landmark regions, links, buttons, form fields, tables,
graphics, and lists. How each category is triggered differs per reader, though.
Screen readers NVDA and Orca assign one letter of the alphabet to each category:
pressing that letter jumps to the next element of that type. VoiceOver on macOS
calls the feature the **Rotor**, a category picker the user opens to choose what
to step through, and also offers a single-letter mode called **Quick Nav** that
behaves like NVDA and Orca.

This is why HTML structure matters so much. Quick navigation only works when the
page has the structure it jumps through. If a page has no headings, the heading
shortcut does nothing. If a page has no landmark regions, the landmark shortcut
does nothing. The user is left to arrow through every single line of content to
find what they need, like reading an entire book that has no table of contents.

##### Focus Mode

Focus mode is the opposite. Every keystroke is passed through to the browser as
if the screen reader were not running, so pressing `H` types the letter "h",
arrow keys move the cursor within a text field, and keyboard shortcuts work
normally. The user is *interacting* with a control rather than *reading* the
page.

Screen readers switch from browse to focus automatically when the user focuses a
native `<input>`, `<textarea>`, or `<select>`: they detect the element's role
and switch modes so the user can type. When the user leaves the control, the
reader switches back to browse mode.

Users can also toggle between modes manually. Manual toggling is sometimes
necessary when interacting with custom widgets that the screen reader does not
automatically recognize.

This automatic mode switching **only works when native HTML elements are used**.
If a native `<select>` is replaced with a custom dropdown built out of `<div>`
elements, the screen reader has no way to know that it is a form control. It
stays in browse mode, and the user cannot interact with it as expected.

#### On Mobile

On smartphones and tablets, there is no physical keyboard by default, so screen
readers cannot rely on intercepted keystrokes. Instead, they **redefine how the
touchscreen behaves**.

When VoiceOver (iOS/iPadOS) or TalkBack (Android) is active:

* **Tapping** an element does not activate it. It **announces** it. The screen
  reader reads aloud what is under the user's finger.
* **Double-tapping** anywhere on the screen activates the currently announced
  element (like clicking it).
* **Swiping right** moves to the next element in DOM order. **Swiping left**
  moves to the previous one. This is the primary way of navigating: the user
  swipes through the page element by element.
* On **iOS/iPadOS**, the **Rotor** (a two-finger twist gesture, like turning a
  dial) lets users select a navigation category: headings, links, form controls,
  landmarks, etc. Once a category is selected, **swiping up/down** moves between
  elements of that type.
* On **Android**, TalkBack uses **reading controls** to achieve the same thing.
  Swipe up-then-down or down-then-up (without lifting the finger) to cycle
  through categories. Once a category is selected, swipe down to move to the
  next element or swipe up to move to the previous one.

These are the mobile equivalents of the desktop quick navigation keys.

Semantic HTML
-------------

With an understanding of how assistive technologies consume HTML, the importance
of **semantic HTML** becomes clear. Before reaching for a `<div>`, check whether
HTML already has a dedicated element for the task. Semantic HTML means using
elements for their intended purpose: `<button>` for actions, `<a>` for links,
`<h1>`-`<h6>` for headings, `<nav>` for navigation, and so on.

Each semantic element carries built-in meaning, keyboard behavior, and screen
reader support. Consider the difference:

```html
<!-- Non-semantic: a <div> styled to look like a button -->
<div class="btn btn-primary">Save</div>

<!-- Semantic: an actual <button> element -->
<button type="submit" class="btn btn-primary">Save</button>
```

These may look identical on screen, but the `<div>` has none of the built-in
behavior that the `<button>` provides. A native `<button>`:

* Is focusable with the keyboard (Tab key).
* Can be activated with Enter or Space.
* Is announced as "button" by screen readers.
* Can be activated by voice control users saying "click Save."
* Submits its parent form when pressed.
* Shows a native focus indicator.

Some of this can be added manually:

* `tabindex="0"` for focus.
* JavaScript handlers for Enter, Space, and click.
* `role="button"` for screen reader announcement.

But the browser provides many subtle behaviors for free: form submission,
`disabled` state management, focus handling, interaction with screen reader
modes, and more. It is easy to miss one. The native element is what guarantees
the keyboard and name/role/value plumbing that WCAG requires ([WCAG 2.1.1
Keyboard][wcag-keyboard], [WCAG 4.1.2 Name, Role, Value][wcag-name-role-value]).

[wcag-keyboard]: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html

The button is just the simplest example. This applies to all native controls. A
particularly common case is the `<select>` element, which developers frequently
replace with custom dropdown menus. A native `<select>` supports keyboard
navigation with arrow keys, type-ahead search, screen reader announcements of
the selected option, and works correctly across all platforms and assistive
technologies. Replicating all of that in a custom dropdown is a significant
undertaking, and the result rarely works as well as the native element.

ARIA
----

When native HTML is not enough (for example, when building a custom widget that
has no native equivalent), [**ARIA**][aria] (Accessible Rich Internet
Applications) fills the gap. It is a set of HTML [attributes][aria-attributes]
and [roles][aria-roles] that add accessibility information to elements. For
example, `role="button"` tells a screen reader that an element behaves like a
button, and `aria-expanded="true"` indicates that a collapsible section is open.
This section covers the most commonly needed attributes, though many more exist
and come up in Rails applications.

[aria]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA
[aria-attributes]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes
[aria-roles]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles

### Naming Elements

Every interactive element needs an **accessible name**, the text that a screen
reader announces and that voice control users say to activate it ([WCAG 4.1.2
Name, Role, Value][wcag-name-role-value]). Native HTML elements get theirs
automatically: a `<button>` from its text content, an `<input>` from its
`<label>`.

[wcag-name-role-value]: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html

The most common situation where a name must be provided manually is **icon-only
buttons**, buttons that contain only an image and no visible text. Without a
name, the screen reader announces just "button" with no indication of what it
does. [`aria-label`][aria-label] solves this by setting the accessible name
directly as a string:

[aria-label]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-label

```html+erb
<%= button_to article_path(@article), method: :delete, aria: { label: "Delete article" } do %>
  <%= image_tag "icons/trash.svg", alt: "" %>
<% end %>
```

The screen reader now announces "Delete article, button" instead of just
"button."

NOTE: The HTML [`title`][title-attr] attribute is sometimes used for the same
purpose, but it is unreliable as the sole source of an accessible name. Browsers
only reveal it as a tooltip on mouse hover, so touch and keyboard users cannot
see it, and screen reader support varies. It can be useful as an additional hint
on an element that already has a visible label or an `aria-label`, but do not
rely on it to name a control.

[title-attr]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/title

Sometimes an element needs a name that is already visible on the page, for
example when a page has multiple `<nav>` elements and screen reader users need
to tell them apart. [`aria-labelledby`][aria-labelledby] solves this by
referencing the `id` of another element whose text should serve as the name:

[aria-labelledby]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-labelledby

```html+erb
<nav aria-labelledby="nav-heading">
  <h2 id="nav-heading">Product Categories</h2>
  <ul>
    <li><%= link_to "Electronics", electronics_path %></li>
    <li><%= link_to "Clothing", clothing_path %></li>
  </ul>
</nav>
```

The screen reader announces "Product Categories, navigation" when the user
reaches this landmark. Prefer `aria-labelledby` over `aria-label` when the
naming text is already visible on the page. It reuses existing content and keeps
a single source of truth, so if someone updates the heading text, the accessible
name updates automatically. With `aria-label`, it is common for someone to
change the visible text and forget to update the attribute, leaving the
accessible name out of sync and the visible label no longer included in the name
voice control users would say ([WCAG 2.5.3 Label in Name][wcag-label-in-name]).

[wcag-label-in-name]: https://www.w3.org/WAI/WCAG22/Understanding/label-in-name.html

The `aria-labelledby` attribute accepts more than one ID, separated by spaces.
This lets the accessible name compose from several existing pieces of page
content without duplicating strings.

#### Naming Best Practices

When an element does have visible text, any `aria-label` or `aria-labelledby`
applied to it must contain that visible text verbatim, ideally as a prefix.
Voice control users issue commands by reading what they see: saying "click Save"
only works if the word "Save" appears in the accessible name. An
`aria-label="Submit form"` on a button whose visible text reads "Save" is a
silent bug for those users, even though a screen reader announces it cleanly.
When in doubt, use `aria-labelledby` pointing at the visible text and let the
browser keep the two in sync.

The accessible name should name the control, not instruct the user how to
operate it. Screen readers already announce the role and how each control is
activated, so an `aria-label="Click button to mark"` or a `<legend
aria-label="Use arrow keys to choose one">` adds noise that conflicts with what
the screen reader says natively. The instruction often does not even apply,
since the user may be on touch or voice control rather than the input method the
hint assumes. The same principle covers pronunciation. Phonetic spellings or
splitting a word across `<span>` letters to make the reader say a name
differently break translation, find-in-page, and braille output, and they
conflict with how the user has configured their reader. Name the control, trust
the native announcement, and rewrite the name itself if it causes friction in
pronunciation.

#### Naming Limitations and Visually Hidden Text

`aria-label` and `aria-labelledby` only work on elements whose **role** supports
naming: interactive elements, landmarks, and other identifiable roles like
`<img>`, `<table>`, `<dialog>`, `group`, or `list`. They are **prohibited** on
elements with a role that does not support naming. A plain `<div>`, `<span>`, or
`<p>` has a role (`generic` or `paragraph`) that prohibits naming, so
`aria-label` on these elements is invalid. However, the restriction is on the
*role*, not the *element*: `<div role="group" aria-label="...">` is valid
because the `group` role supports naming, even though the underlying element is
a `<div>`. The WAI-ARIA specification lists all [roles supporting
naming](https://www.w3.org/TR/wai-aria-1.2/#namefromauthor).

A notification badge is a common case where this goes wrong. Sighted users see a
number beside a bell icon, but the number alone means nothing to a screen
reader, and the instinct is to reach for an `aria-label` on the `<span>`.

```html+erb
<span aria-hidden="true">🔔</span>
<span aria-label="unread notifications">3</span>
```

A plain `<span>` has the `generic` role, which is not meant to carry a label,
making this `aria-label` invalid. Screen readers handle it inconsistently, and
the "unread notifications" label reaches some users while others get only "3"
with no hint of what it counts, so the context cannot be relied on. On an
element whose role *does* support naming the attribute fails the other way,
replacing the accessible name instead of adding to it.

The solution is **visually hidden text**, a `<span>` that is visible to screen
readers but hidden from sighted users with CSS. This is useful for adding
context that `aria-label` cannot convey, for example inside elements whose role
does not support naming, or when the context is part of a larger text flow:

```css
.visually-hidden:not(:focus):not(:active):not(:focus-within) {
  clip-path: inset(50%);
  height: 1px;
  overflow: clip;
  position: absolute;
  white-space: nowrap;
  width: 1px;
}
```

```html+erb
<span aria-hidden="true">🔔</span>
<span>3<span class="visually-hidden"> unread notifications</span></span>
```

The `:not(:focus):not(:active):not(:focus-within)` selector makes the rule apply
only while the element is not focused. A non-focusable element like the `<span>`
above stays hidden for sighted users at all times, while a focusable element
like a skip link becomes visible as soon as it receives focus. A focusable
element that stayed invisible when focused would leave keyboard users tabbing to
something they cannot see, so the single class handles both cases correctly.

The same technique should not be used to extend a link's accessible name beyond
what is visible on screen. A "Learn more" link with a hidden suffix like `<span
class="visually-hidden"> about the new pricing</span>` is a common shortcut, but
it locks out voice control users: those tools require speaking the full
accessible name, and the user has no way of knowing the suffix exists. Make the
visible text descriptive enough on its own ("Learn more about the new pricing")
so the visible name and the accessible name match.

TIP: CSS frameworks ship their own utilities with different APIs: Tailwind
splits the behavior into
[`.sr-only`](https://tailwindcss.com/docs/display#screen-reader-only) and
`focus:not-sr-only`, while Bootstrap provides
[`.visually-hidden`](https://getbootstrap.com/docs/5.3/helpers/visually-hidden/)
and a separate `.visually-hidden-focusable`.

### Describing Elements

Sometimes an element's name alone is not enough. Consider a contact list where
each entry is a button that opens an inline editor for that contact. The
button's name (the contact name) makes sense visually in context, but a screen
reader user navigating button by button hears a list of names with no idea what
activating any of them will do. A password field labeled "Password" does not
tell the user about minimum length requirements either. In these cases, add a
**description**: supplementary text that the screen reader announces after the
name and role.

[`aria-description`][aria-description] sets the description directly as a
string. Use it when the extra context has no visible counterpart on the page:

[aria-description]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-description

```html+erb
<button type="button" aria-description="Edit contact" data-action="inline-edit#show">
  <%= @contact.name %>
</button>
```

The screen reader announces the contact name, then "button", then "Edit
contact", giving the user context about what the button does without changing
its name.

[`aria-describedby`][aria-describedby] references the `id` of another element
that contains the descriptive text. Use it when the description is already
visible on the page, such as a hint below a form field:

[aria-describedby]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-describedby

```html+erb
<%= form.label :password %>
<%= form.password_field :password, aria: { describedby: "password-hint" } %>
<p id="password-hint">Must be at least 12 characters.</p>
```

The screen reader announces the label, the field type, and the description, for
example: "Password, secure text field, Must be at least 12 characters."

Like `aria-labelledby`, `aria-describedby` accepts more than one ID, separated
by spaces, so a description can compose from several existing pieces of page
content without duplicating strings.

NOTE: Unlike `aria-label`, the `aria-description` and `aria-describedby`
attributes are valid on any element, not only ones with a particular role. In
practice, though, a screen reader announces the description reliably only on an
interactive control. On a plain `<div>` or `<span>`, some readers announce it
and others stay silent, so keep descriptions on the control they belong to
rather than relying on them elsewhere.

WARNING: Descriptions are auto-announced every time the element receives focus,
and users cannot always silence them. Do not add a description when the
information is already obvious from the control's name, visible text, or
surrounding context; a redundant description only adds noise on every focus.
When a description is genuinely useful, keep it brief: a short hint like "Must
be at least 12 characters" is helpful, but a multi-sentence paragraph read aloud
every time the user tabs into a field is intrusive.

### Hiding Content

Some elements are purely visual: decorative icons, redundant images, separator
graphics. Screen readers should skip these entirely.
[`aria-hidden="true"`][aria-hidden] removes an element from the accessibility
tree while keeping it visible on screen.

[aria-hidden]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-hidden

A common case is an icon-only button rendered with an inline `<svg>`. The
`aria-label` provides the button's accessible name, and `aria-hidden` on the SVG
keeps the screen reader from announcing the path data on top of the label:

```html
<button aria-label="Delete article">
  <svg aria-hidden="true" viewBox="0 0 24 24">
    <path d="M3 6h18M8 6V4h8v2M5 6l1 14h12l1-14"/>
  </svg>
</button>
```

The example above works cleanly because the SVG cannot be focused and has no
interactive children. However, the rule breaks down when `aria-hidden` sits on
an element that **can** receive focus, or that wraps elements that can. Picture
a keyboard user tabbing across the page when focus suddenly lands inside a
region marked `aria-hidden`. The screen reader says nothing: no role, no label,
no context. The user has no way to tell whether they just landed on a link, a
button, or a form field, let alone what activating it would do. Pressing Enter
runs a control that was never announced.

For a single focusable element, the combination of `aria-hidden` and the
[`tabindex`][tabindex] attribute covers both sides: `tabindex="0"` adds an
element to keyboard navigation; `tabindex="-1"` removes it. Pairing it with
`aria-hidden="true"` keeps that one element out of both the accessibility tree
and the Tab order.

[tabindex]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/tabindex

`tabindex` does not cascade, though. Placing `tabindex="-1"` on a container has
no effect on its descendants, so hiding a subtree this way means annotating
every focusable element inside by hand and keeping those annotations in sync
when the subtree becomes active or inactive.

Consider a carousel that keeps every slide in the DOM so transitions can animate
between them. Each slide has a "Read more" link. Marking the inactive slides
`aria-hidden` hides them from screen readers, but the links inside still receive
focus when the user tabs through the page. The manual fix is to add
`tabindex="-1"` to every focusable element inside every inactive slide, and
remove it from the active one each time the carousel rotates:

```html+erb
<% @slides.each_with_index do |slide, index| %>
  <%= tag.div class: "slide", aria: { hidden: index != @active_index } do %>
    <%= image_tag slide.image, alt: slide.alt %>
    <h3><%= slide.title %></h3>
    <%= link_to "Read more", slide.url, tabindex: (index == @active_index ? nil : -1) %>
  <% end %>
<% end %>
```

With one link per slide this is tolerable; with two or three focusable elements
per slide, and a template that evolves over time, it becomes easy to miss one.

The [`inert`][inert-attr] attribute handles the whole subtree in one
declaration. It removes the content from the accessibility tree, prevents focus
on any descendant, **and** blocks click events inside. Moving `inert` between
the active and inactive slides is enough to keep the carousel accessible as it
rotates, with no `tabindex` bookkeeping:

[inert-attr]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/inert

```html+erb
<% @slides.each_with_index do |slide, index| %>
  <%= tag.div class: "slide", inert: index != @active_index do %>
    <%= image_tag slide.image, alt: slide.alt %>
    <h3><%= slide.title %></h3>
    <%= link_to "Read more", slide.url %>
  <% end %>
<% end %>
```

Rails omits the attribute when the value is `false`, so the active slide renders
without `inert` and every other slide carries it. The single attribute covers
every descendant, including ones added to the template later.

The blocked clicks are the reason `inert` and `aria-hidden` are not
interchangeable. `aria-hidden` only affects the accessibility tree, so a mouse
user can still click through hidden content. `inert` is stricter. Reach for
`inert` when the content should be fully non-interactive, and stay with
`aria-hidden` (alone or with `tabindex="-1"`) when pointer clicks still need to
work.

### Indicating the Current Page

Consider a navigation bar where the active link is visually highlighted with
bold text, a different color, or an underline. A sighted user can immediately
see which page they are on. But a screen reader user hears a list of links that
all sound the same. Nothing tells them which one represents the current page.

[`aria-current="page"`][aria-current] solves this. The screen reader announces
"current page" alongside the link text:

[aria-current]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-current

```html+erb
<nav>
  <ul>
    <li>
      <%= link_to "Home", root_path, aria: { current: ("page" if current_page?(root_path)) } %>
    </li>
    <li>
      <%= link_to "Articles", articles_path,
            aria: { current: ("page" if current_page?(articles_path)) } %>
    </li>
  </ul>
</nav>
```

The same attribute can also be used as a CSS selector, making it the single
source of truth for both the visual style and the screen reader announcement:

```css
[aria-current="page"] {
  font-weight: bold;
  border-bottom: 2px solid currentColor;
}
```

`aria-current` accepts other values for contexts where "page" does not fit:
`step` for a multi-step flow, `location` for the active item in a map or tree,
`date` for a calendar's selected day, `time` for a timeline, or `true` as a
generic fallback.

The same attribute appears in breadcrumb trails. Wrap the trail in `<nav
aria-label="Breadcrumb">` so screen readers can find it as a separate landmark,
and mark the last item with `aria-current="page"` since it represents the page
the user is currently on:

```html+erb
<nav aria-label="Breadcrumb">
  <ol>
    <li><%= link_to "Home", root_path %></li>
    <li><%= link_to "Articles", articles_path %></li>
    <li><%= link_to @article.title, article_path(@article), aria: { current: "page" } %></li>
  </ol>
</nav>
```

When an interface uses tabs whose state lives in the URL, with each tab being a
separate path the server renders, the same `aria-current` pattern works
directly: a `<nav>` with links and `aria-current="page"` on the active tab.
There is also a more elaborate ARIA tabs widget for cases where tab content
changes in place without a URL change, but it is rarely the right tool for
navigation between server-rendered views.

### Toggle Buttons with `aria-pressed`

Some buttons toggle between two states: a like/unlike button, a
complete/incomplete toggle, a mute/unmute switch. A common pattern is to flip a
CSS class to change the button's appearance. But a screen reader user has no way
to perceive a CSS change: they press a button labeled "Like" and hear nothing
about whether they just liked or unliked something.

[`aria-pressed`][aria-pressed] tells the screen reader the button's current
state. It announces "pressed" or "not pressed" along with the button's name,
which is how the toggle state becomes programmatically available ([WCAG 4.1.2
Name, Role, Value][wcag-name-role-value]). A [Stimulus
controller][stimulus-controllers] can manage this, using a value so the initial
state can be set from the server:

[aria-pressed]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-pressed
[stimulus-controllers]: https://stimulus.hotwired.dev/reference/controllers

```js
// app/javascript/controllers/toggle_button_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { pressed: Boolean }

  pressedValueChanged() {
    this.element.ariaPressed = this.pressedValue
  }

  press() {
    this.pressedValue = !this.pressedValue
  }
}
```

```html+erb
<%= tag.button "Like", type: "button",
      data: {
        controller: "toggle-button",
        toggle_button_pressed_value: @article.liked_by?(current_user),
        action: "toggle-button#press" } %>
```

When using `aria-pressed`, do not change the button's text to reflect the state.
If the button says "Like" when unpressed and "Unlike" when pressed, the screen
reader announces "Unlike, pressed", which contradicts itself. Keep the text
stable and let `aria-pressed` carry the state. If the design instead needs the
label itself to change, that is also a valid approach, covered in [Announcing
Dynamic Changes with `aria-live`](#announcing-dynamic-changes-with-aria-live).

Also avoid toggle verbs like "Toggle sidebar" in the label: saying "toggle"
duplicates what `aria-pressed` already communicates. Prefer action verbs like
"Show sidebar": the screen reader announces "Show sidebar, button, pressed" or
"Show sidebar, button, not pressed", which is clear and not redundant.

When the design changes the button text on toggle (for example, "Show completed"
and "Hide completed") instead of carrying `aria-pressed`, the label itself is
what indicates the state. [Announcing Dynamic Changes with
`aria-live`](#announcing-dynamic-changes-with-aria-live) covers how to make that
change reach the screen reader.

TIP: For settings or preferences that toggle between on and off, consider using
a native `<input type="checkbox" switch>` instead. It renders as a toggle switch
and the screen reader announces its on/off state automatically. In browsers that
do not yet support the `switch` attribute, it falls back to a regular checkbox.

### Announcing Dynamic Changes with `aria-live`

[`aria-live`][aria-live] tells screen readers to announce when an element's
content changes. It is useful for flash messages, search results, and other
status updates that the user should perceive without taking focus ([WCAG 4.1.3
Status Messages][wcag-status-messages]).

[aria-live]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-live
[role-status]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role
[role-alert]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/alert_role
[aria-atomic]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-atomic
[aria-relevant]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-relevant
[wcag-status-messages]: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html

There are two levels of urgency:

* **`aria-live="polite"`** (or [`role="status"`][role-status]): The screen
  reader waits until the user is idle before announcing. Use for non-urgent
  updates.
* **`aria-live="assertive"`** (or [`role="alert"`][role-alert]): The screen
  reader interrupts immediately. Use sparingly, for errors and critical warnings
  only.

Two related attributes control what gets announced:

* [`aria-atomic="true"`][aria-atomic]: Announces the **entire** live region
  content when any part changes, not just the changed part. Useful when the
  change only makes sense in context. For example, a clock changing to "12:35
  PM" should announce "12:35 PM", not just "35".
* [`aria-relevant`][aria-relevant]: Controls which types of changes trigger
  announcements. Values can be combined (space-separated):
  * `additions`: New elements added to the region.
  * `text`: Text content changed.
  * `removals`: Elements removed from the region.
  * `all`: Shorthand for `additions removals text`.

  The default is `additions text`, which is almost always what is needed.
  Override it only when a removal is genuinely meaningful on its own.

For example, a button that changes its visible text to reflect the current state
needs a live region so screen readers announce the new label. A Stimulus
controller manages the state with a value, and CSS shows the appropriate text:

```js
// app/javascript/controllers/swap_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { pressed: Boolean }

  toggle() {
    this.pressedValue = !this.pressedValue
  }
}
```

```html+erb
<%= tag.button type: "button",
      data: {
        controller: "swap",
        swap_pressed_value: @showing_completed,
        action: "swap#toggle" } do %>
  <span aria-live="polite" aria-atomic="true" aria-relevant="all">
    <span data-swap-target="primary">Show completed</span>
    <span data-swap-target="secondary">Hide completed</span>
  </span>
<% end %>
```

```css
[data-swap-pressed-value="false"] [data-swap-target="secondary"],
[data-swap-pressed-value="true"] [data-swap-target="primary"] {
  display: none;
}
```

The controller is minimal: it only toggles a boolean. CSS decides which content
is visible based on the value's data attribute. The `aria-live="polite"` region
detects the content change and the screen reader announces the new text.
`aria-atomic="true"` ensures the full label is announced as a whole.
`aria-relevant="all"` is needed here because content is both removed (one span
hidden) and added (the other shown); the default `additions text` would miss the
removal.

WARNING: Use `aria-live` with restraint. If too many elements on the page are
live regions, the screen reader will constantly interrupt the user with
announcements, creating a chaotic experience. Only mark elements as live when
the user genuinely needs to be informed of a change.

### ARIA in Rails View Helpers

As the examples throughout this section show, Rails view helpers support passing
ARIA attributes with the `aria:` option, just like `data:` attributes. This
works in `link_to`, `button_to`, `form_with`, `image_tag`, and all other view
helpers.

When generating HTML dynamically, the [tag helper][tag-helper] accepts the same
`aria:` option.

[tag-helper]: https://api.rubyonrails.org/classes/ActionView/Helpers/TagHelper.html#method-i-tag

A common pattern is iterating over a collection and setting ARIA attributes
conditionally per item. For example, a checkout progress indicator marks the
step the user is currently on:

```html+erb
<nav aria-label="Checkout progress">
  <ol>
    <% @checkout_steps.each do |step| %>
      <%= tag.li aria: { current: ("step" if step == @current_step) } do %>
        <%= link_to step.name, step.path %>
      <% end %>
    <% end %>
  </ol>
</nav>
```

Each `<li>` evaluates `step == @current_step`: the one that matches gets
`aria-current="step"`, the rest get nothing. Rails skips ARIA attributes whose
value is `nil`, but `false` renders as the literal string `"false"` instead, so
reach for `nil` when the attribute should not appear at all. The screen reader
announces "current step" on the active item, so users know where they are in the
flow even when the visual styling alone conveys it.

Helpers also normalize array values. For ARIA attributes that take a
space-separated list of tokens, like `aria-labelledby` and `aria-describedby`,
passing an array joins the entries with a single space and drops `nil` or
`false` entries. This keeps references to other elements declarative even when
the list depends on the state of the record.

### The First Rule of ARIA

The attributes covered above are only the most common ones. ARIA has dozens of
roles, states, and properties, enough to theoretically recreate almost any
native control from scratch: tabs, tree views, comboboxes, grids, and more. With
enough such attributes and JavaScript, a `<div>` can behave like virtually any
widget.

But doing that *correctly* is not trivial and is prone to errors. ARIA can
describe what an element *is*, but it cannot make it *behave* that way. Adding
`role="button"` to a `<div>` tells screen readers that it is a button, but it
does not make the element focusable or keyboard-activatable. The developer still
has to add `tabindex="0"` for focus, implement Enter and Space key handlers, and
handle all other button behaviors by hand. And as the [Semantic
HTML](#semantic-html) section explained, the result rarely matches the quality
of the native element.

This is why [the W3C's first rule][using-aria] is: **if a native HTML element
provides the semantics and behavior required, use it instead of adding ARIA.**

[using-aria]: https://www.w3.org/TR/using-aria/#rule1

NOTE: Incorrect ARIA is worse than no ARIA at all. The [WebAIM Million
report](https://webaim.org/projects/million/) finds year after year that home
pages using ARIA average significantly more detected accessibility errors than
those without it. Only use ARIA when native HTML is truly insufficient for the
use case.

Page Structure
--------------

The highest-level accessibility concern is the overall structure of a page. It
is what screen reader users encounter first and use to orient themselves, just
as sighted users rely on visual layout cues like headers, sidebars, and footers.

### Document Language

Set the [`lang`][lang-attr] attribute on the `<html>` element. Screen readers
use it to select the correct pronunciation rules and speech synthesis voice. If
the language is wrong (for example, `lang="en"` on a page written in Spanish),
they will try to pronounce all the Spanish words with English phonetics, making
the content unintelligible ([WCAG 3.1.1 Language of
Page][wcag-language-of-page]).

[lang-attr]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/lang
[wcag-language-of-page]: https://www.w3.org/WAI/WCAG22/Understanding/language-of-page.html

```html+erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html lang="<%= I18n.locale %>">
```

If a section of the page is in a different language, set `lang` on that element
so the screen reader can switch pronunciation ([WCAG 3.1.2 Language of
Parts][wcag-language-of-parts]):

[wcag-language-of-parts]: https://www.w3.org/WAI/WCAG22/Understanding/language-of-parts.html

```html+erb
<blockquote lang="es">
  <p>La complejidad es un puente que usamos para llegar a la simplicidad.</p>
</blockquote>
```

The quote above is from the [Rails World 2023 Opening
Keynote](https://youtu.be/iqXjGiQ_D-A?t=1302).

### Page Titles

Every page needs a descriptive `<title>`. It is the first thing a screen reader
announces when a page loads, and it appears in browser tabs and bookmarks ([WCAG
2.4.2 Page Titled][wcag-page-titled]):

[wcag-page-titled]: https://www.w3.org/WAI/WCAG22/Understanding/page-titled.html

```html+erb
<%# app/views/layouts/application.html.erb %>
<title><%= content_for(:title) || "My App" %></title>

<%# app/views/articles/show.html.erb %>
<% content_for(:title, @article.title) %>
```

### Landmark Regions

Landmark regions are the major structural areas of a page. Screen reader users
can jump directly between them with their reader's landmark navigation. This is
similar to how a sighted user visually scans for the header, sidebar, or main
content.

Use these HTML5 elements in the layout:

| HTML Element | Landmark | Purpose |
|---|---|---|
| `<header>` | banner | Site-wide header, logo, primary navigation |
| `<nav>` | navigation | Groups of navigation links |
| `<main>` | main | The primary content of the page |
| `<aside>` | complementary | Supporting content related to the main content |
| `<footer>` | contentinfo | Site-wide footer, copyright, secondary links |

A typical Rails layout using landmarks:

```html+erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html lang="<%= I18n.locale %>">
  <head>
    <title><%= content_for(:title) || "My App" %></title>
    <%# ... %>
  </head>
  <body>
    <a href="#main-content" class="visually-hidden" data-turbo="false">
      Skip to main content
    </a>

    <header>
      <%= link_to image_tag("logo.svg", alt: "My App"), root_path %>
      <nav aria-label="Primary">
        <ul>
          <li>
            <%= link_to "Articles", articles_path,
                  aria: { current: ("page" if current_page?(articles_path)) } %>
          </li>
          <li>
            <%= link_to "Pricing", pricing_path,
                  aria: { current: ("page" if current_page?(pricing_path)) } %>
          </li>
          <li>
            <%= link_to "About", about_path,
                  aria: { current: ("page" if current_page?(about_path)) } %>
          </li>
        </ul>
      </nav>
    </header>

    <main id="main-content">
      <%= yield %>
    </main>

    <footer>
      <p>&copy; <%= Date.current.year %> My App</p>
      <nav aria-label="Footer">
        <ul>
          <li>
            <%= link_to "Privacy", privacy_path,
                  aria: { current: ("page" if current_page?(privacy_path)) } %>
          </li>
          <li>
            <%= link_to "Terms", terms_path,
                  aria: { current: ("page" if current_page?(terms_path)) } %>
          </li>
          <li>
            <%= link_to "Contact", contact_path,
                  aria: { current: ("page" if current_page?(contact_path)) } %>
          </li>
        </ul>
      </nav>
    </footer>
  </body>
</html>
```

The logo sits inside the `<header>` and doubles as the link back to the home
page. The `<main>`, page-level `<header>`, and page-level `<footer>` carry no
`aria-label` because each is unique on the page and the role itself identifies
them. A lone `<nav>` or `<aside>` follows the same logic. The two `<nav>`
elements above are an exception, since they share the same role. A screen reader
user navigating by landmark would hear both announced as "navigation" with no
way to tell them apart, so each one carries an `aria-label` ("Primary" and
"Footer") that the screen reader announces alongside the role. Apply the same
approach to any other landmark that repeats on the page.

When the application offers a way to get help (a contact link, a support form, a
help page link), keep it in a consistent place across pages. Rendering it from
the shared layout ensures it appears in the same relative order on every page,
which satisfies [WCAG 3.2.6 Consistent Help][wcag-consistent-help].

[wcag-consistent-help]: https://www.w3.org/WAI/WCAG22/Understanding/consistent-help.html

WARNING: Do not use `role="menu"` or `role="menubar"` for site navigation. Those
roles model desktop application menus with arrow-key navigation and a roving
tabindex, not lists of links. A `<nav>` containing an unordered list of `<a>`
elements is what assistive technology users expect on the web, and adding
`role="menu"` on top changes the keyboard model in ways that break common screen
reader shortcuts.

### Skip Navigation Links

The "Skip to main content" link in the layout above lets keyboard users bypass
the navigation and jump straight to the main content, instead of pressing Tab
through every navigation link on every page ([WCAG 2.4.1 Bypass
Blocks][wcag-bypass-blocks]).

[wcag-bypass-blocks]: https://www.w3.org/WAI/WCAG22/Understanding/bypass-blocks.html

The link uses the [visually hidden focusable
pattern](#naming-limitations-and-visually-hidden-text): hidden by default but
visible when it receives keyboard focus:

```html+erb
<a href="#main-content" class="visually-hidden" data-turbo="false">
  Skip to main content
</a>

<%# ... navigation, header, etc. ... %>

<main id="main-content">
  <%= yield %>
</main>
```

The link works like any anchor link: the `href="#main-content"` points to the
`id` on the `<main>` element, and the browser scrolls to it and moves focus
there when the user activates the link.

### Flash Messages

Flash messages appear after an action: a confirmation that something saved, an
error, a notice. A sighted user sees them, but a screen reader user needs to
hear them. Without an ARIA role, the message just sits there silently and the
user has no idea anything happened ([WCAG 4.1.3 Status
Messages][wcag-status-messages]).

The natural instinct, given the pattern from [Announcing Dynamic Changes with
`aria-live`](#announcing-dynamic-changes-with-aria-live), is to use
`role="status"` for notices and `role="alert"` for errors. But there is a
problem: `role="status"` is polite and only triggers when an existing element's
content changes. Rails flashes do not fit that pattern. After `redirect_to …,
notice: "…"`, the destination page is rendered with the `<p>` containing the
flash message already in place. The message's first appearance is not a "content
changed" event, so a polite live region stays silent.

`role="alert"` is the only role screen readers reliably announce when an element
appears in the DOM for the first time. Use it for every flash, regardless of
type:

```html+erb
<% flash.each do |type, message| %>
  <%= tag.p message, role: "alert" %>
<% end %>
```

Rails uses `notice` and `alert` to distinguish a completed action from an error,
but both need to reach the user the same way. The neutral tone screen readers
use when announcing alerts makes this acceptable in practice.

### Headings

Headings (`<h1>` through `<h6>`) give the page an outline, the equivalent of a
book's table of contents. A screen reader lets the user step through it one
heading at a time, or jump straight to a specific level. Without them, the
reader has to go through everything linearly to find what they need ([WCAG
2.4.10 Section Headings][wcag-section-headings]).

[wcag-section-headings]: https://www.w3.org/WAI/WCAG22/Understanding/section-headings.html

A few rules govern how headings should be used:

* Use a single `<h1>` per page that describes the page content.
* Do not skip heading levels. Go from `<h1>` to `<h2>` to `<h3>` in order.
  Skipping from `<h2>` to `<h4>` breaks the outline and confuses navigation.
* Use headings for **structure**, not for text sizing. For bigger or bolder
  text, use CSS. Heading levels communicate meaning and hierarchy, not visual
  style.

```html+erb
<%# app/views/articles/show.html.erb %>
<h1><%= @article.title %></h1>

<%= @article.body %>

<h2>Comments</h2>
<% @article.comments.each do |comment| %>
  <h3><%= comment.author_name %></h3>
  <p><%= comment.body %></p>
<% end %>

<h2>Related Articles</h2>
<%= render @related_articles %>
```

The immediate payoff is navigation speed. On a page like this one, the heading
shortcut jumps straight from the article title to "Comments" to "Related
Articles", and the level-3 shortcut jumps between comment authors. Without those
headings, a user has to arrow through the article body, every comment, every
link, and every button to find, for example, where the related articles start. A
long thread can turn into minutes of linear reading to reach content that is one
jump away for a sighted user.

Good headings are as much a product decision as a technical one. For every page,
ask what someone would plausibly want to find quickly: the latest comment, the
price, the actions available on an item, the filters, the help text. Those
answers drive which sections deserve a heading, what level they sit at, and what
the text says. Generic labels like "Content" or "Info" waste the mechanism;
specific ones like "Shipping options" or "Payment method" turn it into real
navigation ([WCAG 2.4.6 Headings and Labels][wcag-headings-labels]).

[wcag-headings-labels]: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html

### Grouping Related Content

Sometimes related elements need to be grouped into a logical section that screen
readers can identify, but the section is not important enough to be a landmark.
Landmarks (`<nav>`, `<main>`, `<aside>`, etc.) are for major page sections, and
past five or six on a page they start to add noise rather than help users
orient. For smaller groupings, use [`role="group"`][role-group] with
`aria-label`:

[role-group]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/group_role

```html+erb
<div role="group" aria-label="Share this article">
  <%= link_to "Share on X", share_on_x_url(@article) %>
  <%= link_to "Share via email", share_by_email_url(@article) %>
  <%= tag.button "Copy link", type: "button",
        data: {
          controller: "clipboard",
          clipboard_copyable_value: article_url(@article),
          action: "clipboard#copy" } %>
</div>
```

Screen readers announce "Share this article, group" when the user enters this
area, and "end of group" when they leave. This helps users understand where a
logical section starts and ends without cluttering the landmark navigation, and
makes the grouping programmatic rather than purely visual ([WCAG 1.3.1 Info and
Relationships][wcag-info-relationships]).

[wcag-info-relationships]: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html

NOTE: `role="group"` is the generic version of [`<fieldset>`][fieldset]. Inside
a form, prefer `<fieldset>` with [`<legend>`][legend] for grouping related
controls, as shown in the [Grouping Related
Controls](#grouping-related-controls) section: it is native HTML and works
without ARIA. Reserve `role="group"` for non-form groupings or for cases where
`<fieldset>` styling is not desirable.

[fieldset]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/fieldset
[legend]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/legend

Links and Buttons
-----------------

Links and buttons look similar on screen and are easy to mix up in code, but
they describe two different kinds of control:

* A **link** (`<a>`) takes the user somewhere else: another page, another view,
  an anchor on the same page, or a downloadable resource. Assistive technologies
  announce it as "link".
* A **button** (`<button>`) performs an action on the current page: submitting a
  form, publishing an article, toggling a setting, opening a dialog. Assistive
  technologies announce it as "button".

Screen readers and voice control tools treat the two as separate categories,
each with its own navigation shortcuts and voice commands, as covered in [How
People Use the Web](#how-people-use-the-web). Using a link where a button
belongs (or the other way around) contradicts what the user hears and what they
expect to happen next. Rails view helpers map the distinction to the right
element: [`link_to`][link_to] renders an `<a>`, while [`button_to`][button_to]
renders a real `<form>` around a `<button>`:

[link_to]: https://api.rubyonrails.org/classes/ActionView/Helpers/UrlHelper.html#method-i-link_to
[button_to]: https://api.rubyonrails.org/classes/ActionView/Helpers/UrlHelper.html#method-i-button_to

```html+erb
<%# Navigation: use a link %>
<%= link_to "View profile", profile_path(@user) %>

<%# Action: use a button %>
<%= button_to "Publish", article_publication_path(@article) %>
```

Two patterns commonly blur this line:

* **`<a href="#">` with a JavaScript handler attached.** The `#` is a
  placeholder, since the anchor points nowhere. Screen readers announce the
  element as a link to the same page, so the user expects to be scrolled to
  another section. Landing there and finding that the link performs an action,
  or does nothing at all, contradicts what they were told. Navigating to `#`
  also pushes an empty entry into browser history, so the back button stops
  working as expected. If the control performs an action, use a `<button>` (or
  `button_to`) from the start.

  ```html+erb
  <%# Avoid: an anchor with no destination, wired up with JavaScript %>
  <a href="#" data-action="notification#markAsRead:prevent">Mark as read</a>

  <%# Prefer: a button %>
  <%= button_to "Mark as read", notification_readings_path(@notification) %>
  ```

* **A link for an action that changes server state**, for example `link_to` with
  `data-turbo-method`. Even when the `href` is valid, the semantics are wrong. A
  user hearing "Publish article, link" reasonably expects to navigate to a page
  where they can review the article before submitting. Triggering the action
  directly on activation removes the review they were counting on. Prefer
  `button_to`:

  ```html+erb
  <%# Avoid: a link that immediately publishes the article %>
  <%= link_to "Publish", article_publication_path(@article),
        data: { turbo_method: :post } %>

  <%# Avoid: a link that immediately deletes the article %>
  <%= link_to "Delete", article_path(@article),
        data: { turbo_method: :delete } %>

  <%# Prefer: a button that communicates the correct intent %>
  <%= button_to "Publish", article_publication_path(@article) %>
  <%= button_to "Delete", article_path(@article), method: :delete %>
  ```

A useful thought experiment applies to both anti-patterns. Every browser on
every platform lets the user open a link in a new tab or window. Does it make
sense to open "Publish article" or "Delete" in a new tab? Clearly not. Only
`GET` requests are safe to repeat or open out of context, which is exactly why
actions that change server state should not be links in the first place.

### Buttons inside Other Forms

A common reason developers use `link_to` with `data-turbo-method` is to avoid
nesting forms, for example a delete button inside a form that edits a record.
HTML does not allow nested `<form>` elements, and `button_to` generates its own
`<form>`.

The solution is the HTML [`form`][form-attr] attribute, which associates a
button with a form **anywhere** in the DOM by referencing its `id`:

[form-attr]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/button#form

```html+erb
<%= form_with model: @article do |form| %>
  <%= form.label :title %>
  <%= form.text_field :title %>

  <%= form.label :body %>
  <%= form.text_area :body %>

  <%# This button submits the delete form, not the edit form %>
  <%= tag.button "Delete this article", form: dom_id(@article, :delete_form) %>

  <%= form.submit "Save" %>
<% end %>

<%# The delete form lives outside the edit form as a sibling %>
<%= form_with url: article_path(@article), method: :delete, id: dom_id(@article, :delete_form) do %>
<% end %>
```

The delete button submits its own form even though it is visually rendered
inside the edit form.

### Avoid Nesting Interactive Elements

A natural-looking wish is to make a whole card clickable and still include a
smaller action inside it. Think of a notification in a list: clicking anywhere
on the card opens the notification detail page, but a "Mark as read" button also
lets the user dismiss the notification without navigating away. A common first
attempt is to wrap everything in a link and drop the button within:

```html+erb
<%# Avoid: a button nested inside a link. %>
<%= link_to notification_path(@notification), class: "notification" do %>
  <h3><%= @notification.title %></h3>
  <p><%= @notification.preview %></p>
  <button type="button">Mark as read</button>
<% end %>
```

The markup is invalid. The content model of the [`<a>` element][a-element]
states that it must contain no [interactive content][interactive-content]
descendants (a list that includes `<button>`, nested `<a>`, form controls, and
more), and the [`<button>` element][button-element] carries the same
restriction. Browsers recover from invalid markup in different ways, and the
user experience suffers: a click on the button may navigate to the notification
page instead of marking it as read, because the outer link swallowed the click.
Assistive technology has no clean model either. Screen readers may announce both
roles together (for example, "link, button"), leaving the user unable to tell
which control they just activated, because the role exposed becomes ambiguous
([WCAG 4.1.2 Name, Role, Value][wcag-name-role-value]). The same rule applies to
a link inside another link and to a button inside another button.

[a-element]: https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-a-element
[interactive-content]: https://html.spec.whatwg.org/multipage/dom.html#interactive-content
[button-element]: https://html.spec.whatwg.org/multipage/form-elements.html#the-button-element

The fix is to render the two controls as siblings. The visual design can still
look like a single clickable card: a "stretched link" pseudo-element on the
title link expands its click area over the whole card, while the button sits
above that pseudo-element and keeps its own clicks.

```html+erb
<div class="card">
  <h3>
    <%= link_to @notification.title, notification_path(@notification), class: "stretched-link" %>
  </h3>
  <p><%= @notification.preview %></p>
  <%= button_to "Mark as read", notification_readings_path(@notification) %>
</div>
```

```css
.card {
  position: relative;
}

.card:has(:hover, :focus-visible) {
  background: #f5f5f5;
}

.stretched-link::before {
  content: "";
  position: absolute;
  inset: 0;
}

.card :where(a, button, input, select, textarea):not(.stretched-link) {
  position: relative; /* sits above the pseudo */
}
```

The `:has()` selector lets the whole card react when any of its controls are
hovered or focused, so a single rule covers the stretched title link, the action
button, and any other controls a card might gain later. The `:where()` selector
raises every interactive element above the stretched-link pseudo-element with a
single rule, so cards with extra controls keep working without per-control class
names. Text selection over the card area is captured by the pseudo-element, so
users cannot drag-select the preview text.

The DOM has one link and one button, side by side. Each is independently
focusable, announces its own role, and does what its label says when activated.

WARNING: Stretched-link cards are easy to activate by mistake when the user has
a hand tremor, uses an eye tracker, or taps near the edge on mobile. Never place
an irrevocable or destructive action (delete, cancel, unsubscribe) inside one.
Keep destructive controls in their own deliberate location, with an explicit
confirmation step.

### Link Text

Screen reader users can jump from link to link, or pull up a list of every link
on a page. For that navigation to be useful, each link's text must describe its
destination, either on its own or together with the text immediately around it
([WCAG 2.4.4 Link Purpose][wcag-link-purpose]). Generic phrases like "click
here" or "read more" leave the user with a list of identical-sounding links and
no way to tell them apart.

[wcag-link-purpose]: https://www.w3.org/WAI/WCAG22/Understanding/link-purpose-in-context.html

```html+erb
<%# Avoid: the link text carries no information on its own %>
To read our terms and conditions, <%= link_to "click here", terms_path %>.

<%# Prefer: the link text describes where it leads %>
<%= link_to "Read our terms and conditions", terms_path %>
```

Links that open in a new browser tab or window deserve extra care. The change of
context happens without warning, and keyboard users may lose their place when
focus moves to a new tab. When the behavior is necessary, signal it in the link
text, and include `rel="noopener"` to prevent the new page from gaining access
to the opener window:

```html+erb
<%= link_to "Read the WCAG specification (opens in a new tab)",
      "https://www.w3.org/TR/WCAG22/", target: "_blank", rel: "noopener" %>
```

### Disabled Links

A link with no destination is not really a link. HTML does not have a `disabled`
attribute for `<a>`: applying it has no effect in browsers, and screen readers
ignore it.

When an action that is normally a link should be unavailable, the simplest
answer is to not render a link at all. The classic example is pagination, where
the next control disappears at the end of the list:

```html+erb
<%= link_to "Next", url_for(page: @page.next_param) unless @page.last? %>
```

When `@page.last?` is true, the link is not rendered at all, so screen readers
do not announce a navigation that goes nowhere and sighted users do not see a
dead label.

If the design calls for keeping a faded link in place instead of removing it,
drop the `href`, set `role="link"`, and add `aria-disabled="true"`. The element
still announces as a link, but assistive technologies communicate that it is
currently unavailable:

```html
<a role="link" aria-disabled="true">Next</a>
```

This is rarely necessary in practice. A non-rendered link is simpler for
everyone.

### Icon-Only Buttons

As covered in the [Naming Elements](#naming-elements) section, icon-only buttons
are the most common case where `aria-label` is required:

```html+erb
<%= button_to article_path(@article), method: :delete, aria: { label: "Delete article" } do %>
  <%= image_tag "icons/trash.svg", alt: "" %>
<% end %>
```

The `aria-label` gives the button its accessible name, and the empty `alt`
attribute on the icon keeps the screen reader from announcing the image, as
covered in [Images](#images).

Icon-only buttons are also the most common place where a hit area is too small
for pointer, touch, and low-vision users ([WCAG 2.5.8 Target Size
(Minimum)][wcag-target-size]). Size the button to at least 24 by 24 CSS pixels,
or extend the hit area without changing the visual size. See [Target
Size](#target-size) for the pattern.

[wcag-target-size]: https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html

Multimedia
----------

Images, audio, and video carry content that some users cannot perceive directly:
a blind user cannot see a chart, a deaf user cannot hear narration, and a user
on a noisy bus cannot hear the audio at all. Each medium has its own HTML
element and its own conventions, but the goal is shared: pair the visual or
auditory content with a text alternative that serves the same purpose.

### Images

When a screen reader encounters an image, it looks for alternative text to
announce. Without it, the behavior is unpredictable: some screen readers may try
to read the image filename, some browsers may attempt to generate a description
automatically, and others will simply skip the image. The [`alt`][alt-attr]
attribute provides this alternative text ([WCAG 1.1.1 Non-text
Content][wcag-non-text-content]).

[alt-attr]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/img#alt
[wcag-non-text-content]: https://www.w3.org/WAI/WCAG22/Understanding/non-text-content.html

If an image conveys information that is not available in the surrounding text,
provide a descriptive `alt` that communicates what the image shows. Keep it
concise and to the point. Skip filler like "image of" or "photo of", since
screen readers already announce the role, and do not repeat text that appears
right next to the image:

```html+erb
<%= image_tag "team.jpg", alt: "The Rails core team at Rails World 2024" %>
```

Good `alt` text makes an image accessible, but some images should not be images
in the first place. Prefer real text over images of text: HTML text can be
restyled by the user, translated, searched, and scaled without loss of quality,
while an image of the same text cannot. Logos and short brand marks are
reasonable exceptions; headings, labels, or buttons rendered as images are not
([WCAG 1.4.5 Images of Text][wcag-images-of-text]).

[wcag-images-of-text]: https://www.w3.org/WAI/WCAG22/Understanding/images-of-text.html

Charts, graphs, and other data visualizations deserve extra thought. A short
conclusion ("Sales doubled in Q4") loses information that sighted users can read
off the chart, while a literal description ("bar chart with four bars") leaves
out the data itself. Describe the shape of the data in a sentence or two, and
when the underlying numbers matter, provide them as a real `<table>` next to (or
in place of) the image. Tables have their own accessibility guarantees, covered
in [Tables](#tables):

```html+erb
<figure>
  <%= image_tag "quarterly_sales.png",
        alt: "Bar chart rising from $2.0M in Q1 to $2.4M in Q2, " \
             "dipping to $2.2M in Q3, and peaking at $3.0M in Q4." %>
  <figcaption>Quarterly sales, 2024</figcaption>
</figure>
```

If the table would visually clutter the page, keep it available without making
it the default view. Wrap it in a `<details>` element as shown in [Disclosure
with `<details>` and `<summary>`](#disclosure-with-details-and-summary), or open
it in a dialog as shown in [Dialogs](#dialogs). The data is one interaction away
for anyone who needs it, but the visual layout stays clean.

When an image needs a visible caption as well as alternative text, wrap the
image in a [`<figure>`][figure-el] with a [`<figcaption>`][figcaption-el] as
shown above. The caption describes the image for everyone, while the `alt` still
communicates the same purpose to screen reader users when the caption is not
enough on its own. This pairing tells assistive technology that the caption
belongs to the image instead of leaving that relationship to visual proximity
([WCAG 1.3.1 Info and Relationships][wcag-info-relationships]). Do not wrap the
entire `<figure>` in a link, since that flattens the figure semantics in some
screen readers and produces inconsistent announcements.

[figure-el]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/figure
[figcaption-el]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/figcaption

To offer the same image in several formats, or in different crops for art
direction, wrap the sources in a [`<picture>`][picture-el] element. The
alternative text goes on the inner `<img>` (not on the `<picture>` wrapper),
which Rails [`picture_tag`][picture-tag] configures through the `image:` option:

[picture-el]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/picture
[picture-tag]: https://api.rubyonrails.org/classes/ActionView/Helpers/AssetTagHelper.html#method-i-picture_tag

```html+erb
<%= picture_tag "team.avif", "team.webp", "team.jpg",
      image: { alt: "The Rails core team at Rails World 2024" } %>
```

The browser picks the first format it can render, falls back through the rest,
and uses the last source for the `<img>` element that carries the accessible
alternative.

If an image is purely decorative or redundant (an icon next to text that already
says the same thing), the goal is to keep it out of the accessibility tree
entirely. For visuals that have no meaning of their own, such as textures,
borders, gradients, or subtle patterns, a CSS `background-image` is the cleanest
option: the image never enters the DOM, so no screen reader can reach it. The
trade-off is that `background-image` has no `alt` hook, which is why anything
that actually conveys information must stay a real `<img>`. The same logic
applies to icons inserted through CSS pseudo-elements or icon fonts.

When a decorative image does need to live in the HTML, set `alt` to the empty
string. HTML requires every `<img>` to carry an `alt` attribute, so omitting the
option or passing `alt: nil` renders invalid HTML, and `aria-hidden="true"` does
not exempt the requirement. The empty string is the value that says "decorative"
in HTML's own vocabulary, so screen readers skip `<img alt="">` entirely and no
extra ARIA is needed:

```html+erb
<%# Decorative border %>
<%= image_tag "decorative_border.svg", alt: "" %>

<%# Icon next to text. The text already conveys the meaning. %>
<%= image_tag "icons/email.svg", alt: "" %> Email us
```

Inline SVG is different. An `<svg>` element does not have an `alt` attribute, so
`aria-hidden="true"` is the correct way to remove a decorative SVG from the
accessibility tree:

```html+erb
<svg aria-hidden="true">
  <path d="M2 4l8 5 8-5v12H2z"/>
</svg>
Email us
```

The boundary between decorative and informative is not always obvious. A pricing
comparison table is a good example: each row shows whether a feature is included
in a plan, typically with a check or cross icon. Here the icon *is* the
information. Hiding it with `aria-hidden` leaves the cell empty for screen
reader users, so they cannot tell which plans include which feature. Give these
icons an accessible name:

```html+erb
<%# Feature included: icon carries meaning. %>
<%= image_tag "icons/check.svg", alt: "Included" %>

<%# Feature not included. %>
<%= image_tag "icons/cross.svg", alt: "Not included" %>
```

Informative icons also need enough contrast against their background to be
perceived by sighted users: the same 3:1 ratio that 1.4.11 requires for any
graphical object that conveys meaning ([WCAG 1.4.11 Non-text
Contrast][wcag-non-text-contrast]).

[wcag-non-text-contrast]: https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html

Avatars are another case where context decides. On a user's profile page where
the photo is the focal point, treat it as informative and describe what it
shows. In a list of users where the row already names the person, the avatar
adds nothing for screen reader users, and `alt: ""` keeps the name from being
announced twice.

Emoji deserve a separate note. Screen readers read Unicode emoji like any other
character, so a `✅` inside a heading or a list item gets announced as "check
mark" whether it was placed there for decoration or as a real answer. That means
the same decorative-vs-informative rule applies, but the technique is different.
Do not wrap an emoji in an `<img>`: the image role would add noise on every
focus and hide what is just a character anyway. Put the emoji directly in the
text, and use a surrounding element (`<span>`) to mark it as decorative when
that is the intent:

```html+erb
<%# Decorative: the surrounding text already conveys the meaning. %>
<h2>Results <span aria-hidden="true">🎉</span></h2>

<%# Informative: the emoji is the only signal that the feature is
    included, so leave it exposed to assistive technology. %>
<td>✅</td>
```

### Audio and Video

The standard accessibility tools for time-based media are **captions**,
**transcripts**, and **descriptions**, all of which the native HTML elements
support without third-party libraries.

For audio, use [`audio_tag`][audio-tag] to render an `<audio>` element with
controls and provide a transcript next to it. The transcript is a text version
of everything that was said and any significant non-speech sound, available as
ordinary HTML, so it is searchable, copyable, and indexable. Anyone who needs
the transcript instead of (or alongside) the audio can read it at their own pace
([WCAG 1.2.1 Audio-only and Video-only (Prerecorded)][wcag-audio-only]):

[audio-tag]: https://api.rubyonrails.org/classes/ActionView/Helpers/AssetTagHelper.html#method-i-audio_tag
[wcag-audio-only]: https://www.w3.org/WAI/WCAG22/Understanding/audio-only-and-video-only-prerecorded.html

```html+erb
<%= audio_tag url_for(@episode.audio), controls: true %>

<details>
  <summary>Transcript</summary>
  <%= simple_format(@episode.transcript) %>
</details>
```

Wrapping the transcript in `<details>` keeps the layout clean while making the
text one interaction away.

For video, build the element with the tag helper so caption tracks can be nested
inside. Each [`<track>`][track-el] points to a caption file in [WebVTT][webvtt]
format, and the `default` attribute selects which track loads on its own ([WCAG
1.2.2 Captions (Prerecorded)][wcag-captions]):

[track-el]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/track
[webvtt]: https://developer.mozilla.org/en-US/docs/Web/API/WebVTT_API
[wcag-captions]: https://www.w3.org/WAI/WCAG22/Understanding/captions-prerecorded.html

```html+erb
<%= tag.video controls: true, poster: url_for(@lesson.poster) do %>
  <%= tag.source src: url_for(@lesson.video), type: "video/mp4" %>
  <%= tag.track kind: "captions", src: url_for(@lesson.captions_en),
        srclang: "en", label: "English", default: true %>
  <%= tag.track kind: "captions", src: url_for(@lesson.captions_es),
        srclang: "es", label: "Español" %>
<% end %>
```

The `kind` attribute distinguishes several types of tracks:

* **`captions`**: speech and significant non-speech sound (music cues, applause,
  "phone ringing") for users who cannot hear at all.
* **`subtitles`**: dialogue translated into another language for users who can
  hear the audio but do not understand the spoken language.
* **`descriptions`**: narration of visual content during pauses in the original
  audio, for users who cannot see the screen ([WCAG 1.2.3 Audio Description or
  Media Alternative (Prerecorded)][wcag-audio-description], [WCAG 1.2.5 Audio
  Description (Prerecorded)][wcag-audio-description-aa]).
* **`chapters`**: navigation points so users can jump between sections.

[wcag-audio-description]: https://www.w3.org/WAI/WCAG22/Understanding/audio-description-or-media-alternative-prerecorded.html
[wcag-audio-description-aa]: https://www.w3.org/WAI/WCAG22/Understanding/audio-description-prerecorded.html

When producing a separate description track is not feasible, a full transcript
that captures dialogue, significant non-speech sound, and the visual information
a sighted viewer would receive also satisfies WCAG 1.2.3 as a media alternative.
The same `<details>` pattern shown above for audio works next to a video.

WebVTT files are plain text served as `text/vtt`. A minimal one looks like this:

```
WEBVTT

00:00:00.000 --> 00:00:04.000
Welcome to this introduction to Active Record.

00:00:04.500 --> 00:00:09.000
We will start by creating our first model.
```

Active Storage attachments work directly with `url_for`, so audio and video
served through Active Storage can use the same helpers. Caption tracks are
usually small `.vtt` files attached to the same record.

Audio and video should not start on their own. Sound that begins unannounced
collides with the screen reader a blind user is already listening to, with the
speaker in a meeting, with the silence of a library or public transport. Motion
that starts on its own competes with the rest of the page for attention and is
especially disorienting for users with vestibular conditions or attention
differences. Control of when sound and motion start belongs to the user, not to
the page that loads.

Sound that starts on its own and lasts more than three seconds must be pausable,
stoppable, or muted by the user ([WCAG 1.4.2 Audio
Control][wcag-audio-control]), and moving content that runs longer than five
seconds while sharing the screen with other content must offer a way to pause,
stop, or hide it ([WCAG 2.2.2 Pause, Stop, Hide][wcag-pause-stop-hide]). The
native player covers both for free once the user presses play, so the
recommended default for [`video_tag`][video-tag] and [`audio_tag`][audio-tag] is
to pass `controls: true` and avoid `autoplay`.

[video-tag]: https://api.rubyonrails.org/classes/ActionView/Helpers/AssetTagHelper.html#method-i-video_tag
[wcag-audio-control]: https://www.w3.org/WAI/WCAG22/Understanding/audio-control.html
[wcag-pause-stop-hide]: https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html

Decorative loops in a hero section are the typical exception: muted, looping,
autoplaying. Muting it by default satisfies the audio rule. To honor the motion
rule, gate the source itself with the `media` attribute: when the user has asked
to reduce motion, no source matches and the browser displays the poster image as
a static fallback.

```html+erb
<%= tag.video autoplay: true, muted: true, loop: true,
      playsinline: true, poster: url_for(@hero.poster) do %>
  <%= tag.source src: url_for(@hero.loop),
        media: "(prefers-reduced-motion: no-preference)",
        type: "video/mp4" %>
<% end %>
```

For content video that conveys information rather than decoration, an
alternative way to honor reduced motion is to ship a calmer cut of the same
footage and let the [`media`][source-media] attribute on `<source>` decide which
version to load. The browser walks the sources in order and uses the first one
whose query matches:

[source-media]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/source#media

```html+erb
<%= tag.video controls: true, poster: url_for(@lesson.poster) do %>
  <%= tag.source src: url_for(@lesson.video_calm),
        media: "(prefers-reduced-motion: reduce)", type: "video/mp4" %>
  <%= tag.source src: url_for(@lesson.video), type: "video/mp4" %>
<% end %>
```

The `media` attribute only applies to `<source>` elements. A poster image cannot
vary by preference, so pick one that stays comfortable for any viewer.

Visual content also has to stay below the photosensitive seizure threshold:
nothing on the page may flash more than three times in any one second period
([WCAG 2.3.1 Three Flashes or Below Threshold][wcag-three-flashes]). The
criterion exempts flashes that fall under specific luminance and red-saturation
thresholds, but the practical answer is to keep flashing out of video clips,
animations, and animated images entirely.

[wcag-three-flashes]: https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html

Native `<audio>` and `<video>` controls are keyboard-operable, expose role and
state to assistive technologies, and respect user preferences out of the box.
Custom players require reimplementing all of that by hand and rarely match the
native player's accessibility. Reach for a custom player only when the native UI
cannot meet a strict design requirement.

### Embedded Content

Embedded resources from third parties (a YouTube clip, a slide deck, an external
PDF) usually arrive in an [`<iframe>`][iframe-el]. The frame is opaque to the
parent page, so the surrounding markup has to expose enough information that
users understand what they are about to load and can recover when the embed is
blocked or fails to render.

[iframe-el]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/iframe

```html+erb
<iframe src="https://www.youtube-nocookie.com/embed/-cEn_83zRFw"
        title="Rails World 2024 Opening Keynote"
        allow="autoplay; encrypted-media; picture-in-picture"
        sandbox="allow-scripts allow-same-origin allow-presentation"
        loading="lazy">
</iframe>

<%= link_to "Watch the keynote on YouTube",
      "https://www.youtube.com/watch?v=-cEn_83zRFw" %>
```

The [`title`][iframe-title] is the iframe's accessible name, so a generic value
like "video" leaves screen reader users with the same problem as a generic link
text. The plain link beneath the iframe keeps the content reachable when an
extension blocks the frame, the network is slow, or the user prefers to open it
in their own player. The [`sandbox`][iframe-sandbox] attribute strips the
embed's privileges and re-grants only what it needs through space-separated
tokens, while [`allow`][iframe-allow] opts the embed into browser features the
platform otherwise denies, like autoplay, fullscreen, or picture-in-picture.

[iframe-title]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/iframe#title
[iframe-sandbox]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/iframe#sandbox
[iframe-allow]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/iframe#allow

A `max-height` on the frame keeps it from taking over the viewport when the user
is zoomed in or on a small screen, where a frame at its natural size can leave
the rest of the page out of reach:

```css
iframe {
  max-height: 90vh;
  max-width: 100%;
}
```

Tables
------

A common pattern for displaying tabular data is to use `<div>` elements with CSS
Grid or Flexbox instead of a [`<table>`][table-el]. Visually, this can look
identical to a real table. But for a screen reader user, these are fundamentally
different experiences: the relationships between cells, rows, and headers get
lost ([WCAG 1.3.1 Info and Relationships][wcag-info-relationships]).

[table-el]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/table

When a screen reader encounters a real `<table>`, it enters a special table
navigation mode. It announces the table dimensions ("table with 3 columns and 4
rows"), lets the user move between cells with keyboard shortcuts or gestures,
and reads the column and row headers for each cell automatically. For example,
navigating to a cell might announce "January, North, $10,000", and the user
knows exactly what the value means without having to remember which column they
are in.

A grid of `<div>` elements provides none of this. The screen reader sees a flat
sequence of text with no structure. The user hears "$10,000" without knowing
what it refers to, with no table navigation, no header announcements, and no way
to jump between rows or columns.

Use the `<table>` element for tabular data:

```html+erb
<table>
  <caption>Monthly revenue by region</caption>
  <thead>
    <tr>
      <th scope="col">Region</th>
      <th scope="col">January</th>
      <th scope="col">February</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th scope="row">North</th>
      <td>$10,000</td>
      <td>$12,000</td>
    </tr>
  </tbody>
</table>
```

[`<caption>`][caption-el] gives the table a descriptive title that screen
readers announce when the user navigates to the table. `<th>` with
[`scope="col"`][scope-attr] marks column headers and `scope="row"` marks row
headers. These are what the screen reader reads aloud as the user moves between
cells. The navigation method varies by platform: keyboard shortcuts on desktop
(for example, `Ctrl + Alt + Arrow` keys in NVDA), or gestures on mobile (for
example, in VoiceOver on iOS, swipe left/right moves between columns and the
Rotor set to rows lets users swipe up/down to move between rows).

[caption-el]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/caption
[scope-attr]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/th#scope

If the design truly cannot use a `<table>` element (for example, when the layout
requires CSS Grid or Flexbox), ARIA roles can replicate table semantics. This
preserves screen reader table navigation on non-table elements:

```html
<div role="table" aria-label="Monthly revenue by region">
  <div role="rowgroup">
    <div role="row">
      <div role="columnheader">Region</div>
      <div role="columnheader">January</div>
      <div role="columnheader">February</div>
    </div>
  </div>
  <div role="rowgroup">
    <div role="row">
      <div role="rowheader">North</div>
      <div role="cell">$10,000</div>
      <div role="cell">$12,000</div>
    </div>
  </div>
</div>
```

This gives screen readers the same structure as a native `<table>`, but it
requires significantly more markup and is easier to get wrong. Prefer a native
`<table>` whenever possible.

### Sortable Tables

When a table can be sorted by its column headers, sighted users see a visual
indicator (an arrow, bold text) showing which column is sorted and in which
direction. A screen reader user has no way to perceive these visual cues.

The [`aria-sort`][aria-sort] attribute on the `<th>` communicates the current
sort state programmatically. It accepts `ascending`, `descending`, `none`, or
`other` for a sort order that is neither ascending nor descending. Only the
currently sorted column should have this attribute:

[aria-sort]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-sort

```html+erb
<table>
  <caption>Team members</caption>
  <thead>
    <tr>
      <th><button>Name</button></th>
      <th aria-sort="ascending"><button>Email</button></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Jane Doe</td>
      <td>jane@example.com</td>
    </tr>
    <tr>
      <td>John Smith</td>
      <td>john@example.com</td>
    </tr>
  </tbody>
</table>
```

When the user sorts by a different column, move `aria-sort` to that column's
`<th>` and remove it from the previous one, and if the user clicks the same
column again, toggle between `ascending` and `descending`. Whether the sorting
happens on the server (with Turbo) or on the client (with Stimulus), the
`aria-sort` attribute should always reflect the current state. Since `aria-sort`
already conveys that state to assistive technology, the header label should not
also carry visually hidden text like `, sorted ascending`, which would duplicate
what the screen reader already announces.

### Select-All Checkbox

Bulk-action tables often place a "select all" checkbox at the top of a selection
column to toggle every row at once. Two seemingly natural places to put it are
problematic:

* **In the column header (`<th>`)**: the checkbox label becomes the column
  header for every row beneath it, so the screen reader announces a verbose,
  recursive name on each row checkbox.
* **In the `<caption>`**: the label co-opts the table's accessible name, so the
  table's identity becomes "Select all books" instead of describing what the
  table contains.

Place the select-all checkbox **outside** the table, just before it. The
checkbox keeps its own visible label, the table keeps its caption, and the row
checkboxes are not entangled with either:

```html+erb
<%= form_with url: books_path, method: :delete,
      data: { controller: "selection", turbo_confirm: "Are you sure?" } do |form| %>
  <%= form.checkbox :select_all,
        data: { selection_target: "selectAll", action: "selection#toggleAll" } %>
  <%= form.label :select_all, "Select all books" %>

  <table>
    <caption>Books</caption>
    <thead>
      <tr>
        <th scope="col"><span class="visually-hidden">Select</span></th>
        <th scope="col">Title</th>
        <th scope="col">Author</th>
      </tr>
    </thead>
    <tbody>
      <% @books.each do |book| %>
        <tr>
          <td>
            <%= form.checkbox :book_ids,
                  {
                    multiple: true,
                    data: { selection_target: "item", action: "selection#refresh" },
                    aria: { labelledby: dom_id(book, :title) } },
                  book.id, nil %>
          </td>
          <td id="<%= dom_id(book, :title) %>"><%= book.title %></td>
          <td><%= book.author %></td>
        </tr>
      <% end %>
    </tbody>
  </table>

  <%= form.submit "Delete selected books" %>
<% end %>
```

The first column holds each row's checkbox. Passing `multiple: true` to
[`form.checkbox`][form-checkbox] makes Rails generate a `book_ids[]` name so the
controller receives an array of IDs on submission, and `nil` as the unchecked
value keeps unselected rows out of that array.

[form-checkbox]: https://api.rubyonrails.org/classes/ActionView/Helpers/FormBuilder.html#method-i-checkbox

Each checkbox borrows its accessible name from the title cell next to it through
`aria-labelledby`, which gives the cell an `id` and lets the checkbox reuse that
visible text without duplicating it. The screen reader announces "The Rails Way,
checkbox" instead of an unlabeled "checkbox", and voice control users can
activate any row by saying the title they see on screen.

A Stimulus controller wires the select-all checkbox to the row checkboxes and
keeps both sides in sync. Toggling the `selectAll` target checks every `item`,
and changing any `item` checks the `selectAll` target when every item is
checked, clears it when none are, and sets it to `indeterminate` (the "mixed"
state assistive technology announces) when only some are:

```js
// app/javascript/controllers/selection_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "selectAll", "item" ]

  connect() {
    this.refresh()
  }

  toggleAll() {
    this.itemTargets.forEach(item => item.checked = this.selectAllTarget.checked)
  }

  refresh() {
    this.selectAllTarget.checked = this.#areAllChecked
    this.selectAllTarget.indeterminate = this.#isAnyChecked && !this.#areAllChecked
  }

  get #areAllChecked() {
    return this.itemTargets.every(item => item.checked)
  }

  get #isAnyChecked() {
    return this.itemTargets.some(item => item.checked)
  }
}
```

WARNING: Never apply CSS `display` properties (`flex`, `grid`, `block`) to table
elements (`<table>`, `<tr>`, `<td>`, `<th>`). These override the native table
semantics, breaking everything described above.

Forms
-----

Forms are the primary way users interact with web applications. A form that is
visually clear but poorly structured in HTML can be completely unusable for
keyboard, screen reader, and voice control users.

### Labels

Every form control must have a **label**, a visible piece of text that
identifies what it is for ([WCAG 3.3.2 Labels or
Instructions][wcag-labels-instructions]). Screen readers announce it on focus.
Without one, a screen reader user hears only the field type (for example, "edit
text, blank") with no indication of what to type. Voice control users cannot
refer to the field by name.

[wcag-labels-instructions]: https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html

Rails form helpers automatically generate the `<label>` and `<input>` pairing:

```html+erb
<%= form_with model: @user do |form| %>
  <%= form.label :name %>
  <%= form.text_field :name %>

  <%= form.label :email_address %>
  <%= form.email_field :email_address %>

  <%= form.submit %>
<% end %>
```

This generates HTML where each `<label>` has a `for` attribute matching the
`<input>`'s `id`:

```html
<label for="user_name">Name</label>
<input type="text" name="user[name]" id="user_name">
```

This explicit association has multiple benefits: screen readers announce "Name"
when the input is focused, voice control users can say "click Name" to focus the
field, and clicking the label focuses the input (enlarging the clickable area).

WARNING: Never rely on the [`placeholder`][placeholder-attr] attribute as a
substitute for a label. Placeholders disappear once the user starts typing, both
visually and for screen readers. If a user needs to review what a field is for,
the placeholder is already gone and they have no way to check without clearing
the field.

[placeholder-attr]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input#placeholder

#### Label Order

As covered in [How Screen Readers Work](#how-screen-readers-work), screen
readers read content in DOM order. The order of labels and controls matters: for
text fields, selects, and textareas, the label should come **before** the
control. For checkboxes and radio buttons, the label comes **after**:

```html+erb
<%# Text fields, selects, textareas: label before the control %>
<%= form.label :name %>
<%= form.text_field :name %>

<%= form.label :country %>
<%= form.select :country, country_options %>

<%# Checkboxes: label after the control %>
<%= form.checkbox :terms %>
<%= form.label :terms, "I accept the terms" %>

<%# Radio buttons: label after each control, grouped with fieldset %>
<fieldset>
  <legend>Billing plan</legend>

  <%= form.radio_button :plan, "monthly" %>
  <%= form.label :plan_monthly, "Monthly" %>

  <%= form.radio_button :plan, "yearly" %>
  <%= form.label :plan_yearly, "Yearly" %>
</fieldset>
```

This matches the visual convention users expect: they see "Name" followed by an
input, or a checkbox followed by its text. If the label for a text field comes
after the input, the screen reader still announces the label when the field is
focused (because the label and input are associated with `for`/`id`), but a user
navigating in browse mode encounters the input before its label. That is
confusing, because browse mode reads through content sequentially and users
expect to know what a field is for before they reach it.

#### Wrapping Labels

An alternative to the `for`/`id` pairing is to **wrap** the form control inside
a `<label>` element. The association is implicit, so no `for` or `id` attributes
are needed:

```html+erb
<label>
  Name
  <%= form.text_field :name %>
</label>
```

Wrapping labels are useful when managing `for`/`id` pairs becomes cumbersome,
for example in designs where the label and input should be treated as a single
visual unit (inline forms, checkbox or radio lists), or when multiple forms on
the same page make ID pairing difficult.

WARNING: A wrapping label must contain exactly **one** form control. A `<label>`
can only be associated with a single control, so wrapping multiple controls in
one label will produce unexpected behavior.

### Grouping Related Controls

Use [`<fieldset>`][fieldset] and [`<legend>`][legend] to group related controls.
This is essential for radio buttons and checkboxes, where each individual
control has its own label but the group as a whole also needs a name. Without a
`<fieldset>`, a screen reader user hearing "Monthly" and "Yearly" radio buttons
has no idea what they apply to ([WCAG 1.3.1 Info and
Relationships][wcag-info-relationships]).

The [`fieldset_tag`][fieldset_tag] helper renders both the `<fieldset>` and its
`<legend>` in one call. A radio group picking the billing cycle:

[fieldset_tag]: https://api.rubyonrails.org/classes/ActionView/Helpers/FormTagHelper.html#method-i-fieldset_tag

```html+erb
<%= form_with model: @subscription do |form| %>
  <%= fieldset_tag "Billing cycle" do %>
    <%= form.radio_button :billing_cycle, "monthly" %>
    <%= form.label :billing_cycle_monthly, "Monthly" %>

    <%= form.radio_button :billing_cycle, "yearly" %>
    <%= form.label :billing_cycle_yearly, "Yearly" %>
  <% end %>
<% end %>
```

A checkbox group picking multiple tags on an article:

```html+erb
<%= form_with model: @article do |form| %>
  <%= fieldset_tag "Tags" do %>
    <%= form.collection_checkboxes :tag_ids, Tag.all, :id, :name %>
  <% end %>
<% end %>
```

When the user focuses any control inside the fieldset, the screen reader
announces the `<legend>` first, so the group's purpose is clear before the
individual control is read.

### Avoiding ID Collisions with `namespace`

Rails form helpers generate IDs automatically (for example, `user_email_address`
for a `User` model's `email_address` field). When the same form appears multiple
times on a page (a list of items where each one renders an inline edit form, for
example), every input would get the same ID. Duplicate IDs are invalid HTML, so
labels and ARIA associations that reference them will not be correctly paired
with their controls.

Use the [`namespace`][form_with-options] option on [`form_with`][form_with] to
prefix all generated IDs:

[form_with-options]: https://api.rubyonrails.org/classes/ActionView/Helpers/FormHelper.html#method-i-form_with-label-form_with+options
[form_with]: https://api.rubyonrails.org/classes/ActionView/Helpers/FormHelper.html#method-i-form_with

```html+erb
<% @contacts.each do |contact| %>
  <%= form_with model: contact, namespace: dom_id(contact) do |form| %>
    <%= form.label :name %>
    <%= form.text_field :name %>
    <%# First contact generates: <input id="contact_1_contact_name" ...> %>
    <%# Second contact generates: <input id="contact_2_contact_name" ...> %>
    <%= form.submit "Save" %>
  <% end %>
<% end %>
```

The `namespace` is automatically applied to all generated IDs within the form,
including those created by [`field_id`][field_id], so `aria-describedby` and
similar associations continue to work correctly.

[field_id]: https://api.rubyonrails.org/classes/ActionView/Helpers/FormBuilder.html#method-i-field_id

### Validation Errors

When a form submission fails, the user needs to know what went wrong and which
field to fix. When possible, the error message should also describe how to
correct the input ([WCAG 3.3.3 Error Suggestion][wcag-error-suggestion]). This
seems straightforward, but many common validation patterns create serious
accessibility barriers:

[wcag-error-suggestion]: https://www.w3.org/WAI/WCAG22/Understanding/error-suggestion.html

* **Disabling the submit button** until all fields are valid. The user cannot
  submit the form, but has no way to know *why*. They have to navigate every
  field searching for the problem. A keyboard or screen reader user may never
  find it ([WCAG 3.3.1 Error Identification][wcag-error-identification]).
* **Showing errors only after submission** without focusing the first invalid
  field. The user submits, the page re-renders with error messages somewhere in
  the form, but focus stays at the top of the page. The user must navigate
  through the entire form to discover where the errors are.
* **Indicating errors only with color**: a red border, a red background. Screen
  readers do not convey color. A screen reader user has no way to know the field
  is invalid. Users with color blindness may not distinguish the red from the
  normal state ([WCAG 1.4.1 Use of Color][wcag-use-of-color]).

[wcag-error-identification]: https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html
[wcag-use-of-color]: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html

The browser's built-in [constraint validation
API](https://developer.mozilla.org/en-US/docs/Web/HTML/Constraint_validation)
addresses each of these: it **automatically focuses the first invalid field**,
shows a native error tooltip that screen readers announce, and prevents
submission until errors are fixed, all without ARIA or custom JavaScript.

#### Native Validation Attributes

For simple constraints, use native HTML validation attributes:

```html+erb
<%= form_with model: @user do |form| %>
  <%= form.label :email_address %>
  <%= form.email_field :email_address, required: true %>

  <%= form.label :password %>
  <%= form.password_field :password, required: true, minlength: 12 %>

  <%= form.submit %>
<% end %>
```

When the user submits the form and a field is invalid, the browser focuses the
first invalid field and shows the error. No JavaScript needed.

Valid and invalid fields can be styled using the [`:valid`][css-valid] and
[`:invalid`][css-invalid] CSS pseudo-classes. The
[`:user-valid`][css-user-valid] and [`:user-invalid`][css-user-invalid] variants
are more useful in practice: they only apply after the user has interacted with
the field, so fields do not appear invalid before the user has had a chance to
fill them in:

[css-valid]: https://developer.mozilla.org/en-US/docs/Web/CSS/:valid
[css-invalid]: https://developer.mozilla.org/en-US/docs/Web/CSS/:invalid
[css-user-valid]: https://developer.mozilla.org/en-US/docs/Web/CSS/:user-valid
[css-user-invalid]: https://developer.mozilla.org/en-US/docs/Web/CSS/:user-invalid

```css
input:user-invalid {
  border-color: #c00000;
}
```

TIP: If conditional validation is needed, consider toggling native validation
attributes dynamically with Stimulus instead of writing custom validators. For
example, a controller can add or remove the `required` attribute on a field
based on another field's value, and the browser's validation API does the rest.

#### Server-Side Errors

Some validations can only run on the server: uniqueness is a common example.
Consider a registration form where the server rejects an email address that is
already taken. The error needs to surface the same way as native validation:
focus the field, show the message, and let the user correct it.

The bridge is [`setCustomValidity`][setCustomValidity], which sets a custom
error message on a field that the browser treats the same as a native validation
error. When the server re-renders the form with errors, two small Stimulus
controllers route each error into the browser's validation API: a `field`
controller on each invalid field, and a `form` controller on the form itself.

[setCustomValidity]: https://developer.mozilla.org/en-US/docs/Web/API/HTMLInputElement/setCustomValidity

```html+erb
<%= form_with model: @user,
      data: {
        controller: "form",
        action: ("turbo:render@document->form#reportValidity" if @user.errors.any?) } do |form| %>
  <%= form.label :email_address %>
  <%= form.email_field :email_address,
        data: {
          controller: "field",
          field_custom_validity_value: @user.errors.full_messages_for(:email_address).to_sentence,
          action: "input->field#clearCustomValidity" } %>

  <%= form.submit %>
<% end %>
```

The `field` controller wraps `setCustomValidity` so the message can come from a
[Stimulus value][stimulus-values] rendered into the HTML by the server:

[stimulus-values]: https://stimulus.hotwired.dev/reference/values

```js
// app/javascript/controllers/field_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { customValidity: String }

  customValidityValueChanged() {
    this.element.setCustomValidity(this.customValidityValue || "")
  }

  clearCustomValidity() {
    this.customValidityValue = ""
  }
}
```

The controller is attached directly to the form field: the field itself is
`this.element`. When the value changes, `customValidityValueChanged` pushes the
message to the browser, and an empty string clears it.

The `clearCustomValidity` action is what makes the form recoverable: when the
server marks an email as already taken, the browser keeps that custom validity
message until something clears it. Without this action, the user could correct
the email and still be blocked by the original tooltip on the next submit.
Reacting to `input` clears the message the moment the user starts editing, so
the next submit goes through and the server has a chance to validate the new
value.

The `form` controller calls [`reportValidity()`][form-reportValidity] on the
`<form>` once Turbo has rendered the re-submitted form, which locates the first
invalid field, focuses it, and shows the tooltip, matching what native
client-side validation does:

[form-reportValidity]: https://developer.mozilla.org/en-US/docs/Web/API/HTMLFormElement/reportValidity

```js
// app/javascript/controllers/form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  reportValidity() {
    this.element.reportValidity()
  }
}
```

The [action descriptor][stimulus-action-descriptors] only appears in the markup
when `@user.errors.any?`, so `reportValidity()` runs just when there is
something to report. Without that guard, the same action would also fire on the
initial page render (when the form has no errors yet) and on any other Turbo
render that happens while the form is in the DOM, which would show stale or
empty validation UI.

[stimulus-action-descriptors]: https://stimulus.hotwired.dev/reference/actions#descriptors

The `@document` suffix attaches the listener to `document`, which is where Turbo
fires [`turbo:render`][turbo-render]. By the time this event is dispatched,
Turbo has swapped the new markup in and Stimulus has processed the updated
dataset, so the field already has its custom validity message ready for
`reportValidity()` to display.

[turbo-render]: https://turbo.hotwired.dev/reference/events#turbo%3Arender

#### Client-Side Errors

Some validations do not need the server at all: anything comparing two fields
already on the page, for example, can run entirely in the browser. Password
confirmation is a typical case. A `password-match` controller observes both
password fields and calls `setCustomValidity` on the confirmation field whenever
they differ:

```html+erb
<%= form_with model: @user do |form| %>
  <%= tag.div data: {
        controller: "password-match",
        password_match_mismatch_message_value: t("errors.messages.confirmation",
          attribute: User.human_attribute_name(:password)) } do %>
    <%= form.label :password %>
    <%= form.password_field :password, data: { password_match_target: "originalInput" } %>

    <%= form.label :password_confirmation %>
    <%= form.password_field :password_confirmation,
          data: {
            password_match_target: "confirmationInput",
            action: "input->password-match#verify" } %>
  <% end %>

  <%= form.submit %>
<% end %>
```

The mismatch message is stored as a Stimulus value rather than hardcoded in
JavaScript, so Rails renders it with `I18n` and the user's locale is respected
automatically:

```js
// app/javascript/controllers/password_match_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "originalInput", "confirmationInput" ]
  static values = { mismatchMessage: String }

  verify() {
    this.confirmationInputTarget.setCustomValidity(
      this.#isMatch ? "" : this.mismatchMessageValue
    )
  }

  get #isMatch() {
    return this.originalInputTarget.value === this.confirmationInputTarget.value
  }
}
```

Both paths use the same browser API, `setCustomValidity`. At submit time, the
browser treats any non-empty validity message exactly like a native validation
error. Submission is blocked, focus moves to the first invalid field, and a
tooltip shows the message.

WARNING: As covered in [Validation Errors](#validation-errors), never disable
the submit button when there are validation errors. Let the browser's validation
API focus the first invalid field automatically.

#### Real-Time Validation Feedback

The client-side example above validates on input, but the error tooltip only
appears once the user tries to submit. To surface the error the moment the two
fields stop matching, ask the field to report its validity right after setting
it:

[input-reportValidity]: https://developer.mozilla.org/en-US/docs/Web/API/HTMLInputElement/reportValidity

```js
verify() {
  this.confirmationInputTarget.setCustomValidity(
    this.#isMatch ? "" : this.mismatchMessageValue
  )
  this.confirmationInputTarget.reportValidity()
}
```

[`reportValidity()`][input-reportValidity] surfaces the input's validity state.
The field is already focused since the user is typing in it, so the tooltip
appears next to it the moment the typed character breaks the match.

#### Validation with ARIA

If the native validation UI does not fit the design (for example, when error
messages need to be styled as part of the page rather than browser tooltips),
[`aria-invalid`][aria-invalid] and [`aria-errormessage`][aria-errormessage] can
be used instead. The two attributes are paired: `aria-invalid="true"` marks the
field as in error, and `aria-errormessage` points at the element holding the
message.

[aria-invalid]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-invalid
[aria-errormessage]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-errormessage

```html+erb
<%= form_with model: @user do |form| %>
  <div>
    <%= form.label :email_address %>
    <%= form.email_field :email_address,
          aria: {
            invalid: @user.errors[:email_address].any?,
            errormessage: (form.field_id(:email_address, :error) if @user.errors[:email_address].any?) } %>
    <% if @user.errors[:email_address].any? %>
      <p id="<%= form.field_id(:email_address, :error) %>">
        <%= @user.errors.full_messages_for(:email_address).to_sentence %>
      </p>
    <% end %>
  </div>

  <%= form.submit %>
<% end %>
```

The `form.field_id(:email_address, :error)` helper generates a consistent ID
(for example, `user_email_address_error`) that ties the error message to the
input. Since it uses the same form builder, it also respects the `namespace`
option described in [Avoiding ID
Collisions](#avoiding-id-collisions-with-namespace), so these associations work
correctly even when the same form appears multiple times on a page. When the
screen reader focuses the field, it reads: "Email address, edit text, invalid,
has already been taken." The error message is announced because
`aria-errormessage` only becomes active when `aria-invalid="true"`, so a field
that returns to a valid state stops carrying the message in its accessible
description.

The same field often also needs a persistent hint, like a password policy or a
format reminder. With `aria-describedby` and `aria-errormessage` paired, the two
roles separate cleanly: the hint stays attached every render through
`describedby`, and the error joins through `errormessage` only when there is
something to report.

```html+erb
<%= form.label :password %>
<%= form.password_field :password,
      aria: {
        describedby: form.field_id(:password, :hint),
        invalid: @user.errors[:password].any?,
        errormessage: (form.field_id(:password, :error) if @user.errors[:password].any?) } %>
<p id="<%= form.field_id(:password, :hint) %>">
  At least 12 characters, with one number.
</p>
<% if @user.errors[:password].any? %>
  <p id="<%= form.field_id(:password, :error) %>">
    <%= @user.errors.full_messages_for(:password).to_sentence %>
  </p>
<% end %>
```

The screen reader reads the label, the field, the invalid state if present, the
hint, and finally the error message when one exists. The hint announcement stays
stable across submissions because it lives in `describedby`; the error only
enters the announcement on the renders where `aria-invalid` is `true`.

Unlike native validation, ARIA validation does not focus the first invalid field
automatically, so the application has to do it. In a long form, a common way to
handle this is to render a summary of every error at the top of the form and
move focus there: an `<h2>` followed by a `<ul>` of messages, with focus moved
to the heading and each item linking to the field it describes.

```html+erb
<% if @user.errors.any? %>
  <h2 tabindex="-1" autofocus>
    <%= pluralize(@user.errors.count, "error") %> prohibited this
    user from being saved:
  </h2>
  <ul>
    <% @user.errors.each do |error| %>
      <li>
        <%= link_to error.full_message, "##{form.field_id(error.attribute)}" %>
      </li>
    <% end %>
  </ul>
<% end %>
```

`tabindex="-1"` on the `<h2>` makes it focusable without adding it to the Tab
order, and `autofocus` sends focus to it after the server re-renders the form.
Screen readers announce the heading and let the user navigate through the list
of errors; activating one jumps to the field that needs correction. Do not
combine this pattern with the native `reportValidity()` flow from [Server-Side
Errors](#server-side-errors): both try to place focus at the same moment and
compete with each other.

### Identifying Input Purpose

Give each form field the most specific `type` the HTML spec provides (`email`,
`tel`, `url`, `number`, `date`, `password`, `search`, and so on), and set the
[`autocomplete`][autocomplete-attr] attribute on fields that collect the user's
own information:

* The right `type` triggers native validation (an `email` field rejects
  malformed addresses) and brings up the right on-screen keyboard on mobile (a
  `tel` field shows a numeric keypad).
* `autocomplete` lets the browser fill the field from saved data and password
  managers recognize `new-password` and `current-password` fields so their
  suggestions are useful.
* Both attributes tell assistive technology what the field is for, beyond what
  the label alone conveys ([WCAG 1.3.5 Identify Input
  Purpose][wcag-identify-input-purpose]).

Use the standard HTML [input types][input-types] and the [WHATWG autocomplete
token list][autocomplete-tokens] (`name`, `email`, `tel`, `street-address`,
`postal-code`, `cc-number`, `new-password`, `current-password`, `one-time-code`,
and so on).

[input-types]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input#input_types
[autocomplete-attr]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/autocomplete
[autocomplete-tokens]: https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#autofill
[wcag-identify-input-purpose]: https://www.w3.org/WAI/WCAG22/Understanding/identify-input-purpose.html

```html+erb
<%= form_with model: @user do |form| %>
  <%= form.label :email_address %>
  <%= form.email_field :email_address, autocomplete: "email" %>

  <%= form.label :phone %>
  <%= form.telephone_field :phone, autocomplete: "tel" %>

  <%= form.label :password %>
  <%= form.password_field :password, autocomplete: "current-password" %>
<% end %>
```

On numeric fields where `type="number"` is not appropriate (for example a
verification code, where a leading zero matters), set the
[`inputmode`][inputmode-attr] attribute to tell mobile keyboards which layout to
show. Values like `numeric`, `decimal`, and `tel` bring up the right keypad
without changing HTML validation:

[inputmode-attr]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/inputmode

```html+erb
<%= form.text_field :verification_code, autocomplete: "one-time-code", inputmode: "numeric" %>
```

For password fields paired with `has_secure_password`, distinguish between
registration and sign-in so password managers can help. Use `autocomplete:
"new-password"` on both the password and the confirmation during registration;
use `autocomplete: "current-password"` on the password field in the sign-in
form:

```html+erb
<%# app/views/users/new.html.erb %>
<%= form.password_field :password, autocomplete: "new-password" %>
<%= form.password_field :password_confirmation, autocomplete: "new-password" %>

<%# app/views/sessions/new.html.erb %>
<%= form.password_field :password, autocomplete: "current-password" %>
```

Password managers and authenticators rely on these tokens to identify credential
fields. Providing them is also the first step toward meeting [WCAG 3.3.8
Accessible Authentication (Minimum)][wcag-accessible-authentication], which
requires that authentication does not depend on a cognitive function test such
as remembering a password or solving a puzzle. When native authentication is not
possible, alternatives that satisfy the criterion include single-use codes
delivered by email or SMS (paired with `autocomplete="one-time-code"`), magic
links, and passkeys or other WebAuthn-based flows. If a CAPTCHA is required,
choose one that verifies passively (a single checkbox, silent device checks)
over one that asks the user to identify images or transcribe characters.

[wcag-accessible-authentication]: https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication-minimum.html

Ask for data the user has already provided only when strictly necessary. When
the same information appears twice in a flow (a shipping address reused for
billing, a name repeated across steps), pre-fill the field or offer a "same as
shipping" checkbox instead of making the user retype it ([WCAG 3.3.7 Redundant
Entry][wcag-redundant-entry]).

[wcag-redundant-entry]: https://www.w3.org/WAI/WCAG22/Understanding/redundant-entry.html

### Avoiding Surprises on Focus and Input

An application should only change the context of the page when the user asks it
to. "Changing the context" means taking the user somewhere new: navigating to
another page, opening a dialog that takes over the viewport, or moving focus to
a distant region. Actions as small as focusing a field or changing its value can
trigger that kind of change.

The first is **opening a dialog or navigating the moment a field receives
focus**. Picture a user filling out a form with the keyboard: Tab, Tab, Tab.
When focus lands on a date-of-birth field, a custom date picker takes over. A
dialog opens, focus is dragged inside, and the rest of the form disappears
behind an overlay. The user presses Escape to get back to where they were, focus
returns to the same field, and the dialog opens again immediately. The field
becomes a trap: every time focus touches it, the application hijacks the page.
Trigger the opening from an explicit click or Enter press, never from focus
alone ([WCAG 3.2.1 On Focus][wcag-on-focus]).

The second is **navigating the moment a control's value changes**. A country
selector that submits the form on every change is the typical case. A keyboard
user opens the selector, presses the Down arrow once to pick a different
country, and the form submits on that single change. The page reloads. To try
another country the user has to find the selector again, open it, and pick.
Every change costs them the round trip. Pair the select with a submit button so
the navigation happens only when the user asks for it ([WCAG 3.2.2 On
Input][wcag-on-input]).

[wcag-on-focus]: https://www.w3.org/WAI/WCAG22/Understanding/on-focus.html
[wcag-on-input]: https://www.w3.org/WAI/WCAG22/Understanding/on-input.html

Updating content in place is different, and welcome. A search field that filters
results as the user types, or a form that swaps its list of provinces when the
user picks a country, does not change the context: the user stays on the same
page, with the same focus and the same tab order. Only the fragment of content
that needs to change does.

### Disabling Controls Carefully

The `disabled` attribute marks a control as unavailable: the browser blocks
interaction and screen readers announce the disabled state. It is the right tool
when a control is genuinely unavailable, such as a feature behind a paid plan, a
payment method not offered in the user's country, or a field that does not apply
given another selection.

Two practices keep `disabled` usable:

* **Style the disabled state** so it stays readable without losing the disabled
  cue. Both [WCAG 1.4.3 Contrast (Minimum)][wcag-contrast] and [WCAG 1.4.11
  Non-text Contrast][wcag-non-text-contrast] exempt inactive controls, so
  browser defaults can render them at very low contrast. A small CSS rule
  overrides the default while still signaling the state:

  ```css
  :disabled {
    opacity: 0.6;
    cursor: default;
  }
  ```

* **Explain why nearby**, in visible text or in the surrounding layout. A
  disabled control cannot answer "why" on its own, so the context has to live
  around it.

[wcag-contrast]: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html

When an action would normally be allowed but is briefly unavailable (while a
form submission is in flight), `disabled` causes the button to lose focus and
disappear from the page's keyboard model. [Form Submitter
State](#form-submitter-state) covers `aria-disabled="true"` as the alternative
for this case, where the button has to remain reachable while submission is in
progress.

### Custom Appearance

Native checkboxes, radio buttons, range sliders, and other form controls handle
keyboard operation, programmatic roles and states, and accessible names
automatically. When the default look does not fit the design, CSS can take over
without giving up any of that.

For light branding, the [`accent-color`][accent-color] property tints
checkboxes, radio buttons, range sliders, and `<progress>` elements with a
single declaration:

```css
:root {
  accent-color: #4A90D9;
}
```

For full custom styling, [`appearance: none`][appearance] resets the browser's
default rendering and lets CSS draw the control. The `<input>` stays in the DOM,
so the browser keeps handling focus, the indeterminate state, and right-to-left
layouts, and only the visual presentation changes:

```css
input[type="checkbox"] {
  appearance: none;
  inline-size: 1.25rem;
  block-size: 1.25rem;
  border: 0.125rem solid currentColor;
  border-radius: 0.25rem;
}

input[type="checkbox"]:checked {
  background: currentColor;
}
```

Add similar rules for the other states the design needs
([`:focus-visible`][focus-visible], [`:indeterminate`][indeterminate],
[`:disabled`][disabled]).

[focus-visible]: https://developer.mozilla.org/en-US/docs/Web/CSS/:focus-visible

Either approach is simpler and more accessible than recreating controls with
`<div>` and custom ARIA, a pattern that regresses what native elements provide
automatically.

[accent-color]: https://developer.mozilla.org/en-US/docs/Web/CSS/accent-color
[appearance]: https://developer.mozilla.org/en-US/docs/Web/CSS/appearance
[indeterminate]: https://developer.mozilla.org/en-US/docs/Web/CSS/:indeterminate
[disabled]: https://developer.mozilla.org/en-US/docs/Web/CSS/:disabled

Native HTML for Common Patterns
-------------------------------

Modern HTML provides native elements for interactive patterns that previously
required JavaScript libraries. These native elements are accessible by default:
they handle keyboard interaction, focus management, and screen reader
announcements automatically.

### Disclosure with `<details>` and `<summary>`

The [`<details>`][details-el] element creates a disclosure widget: content that
is hidden until the user expands it. No JavaScript is needed:

[details-el]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/details

```html+erb
<details>
  <summary>Advanced options</summary>
  <div>
    <%# Content revealed when expanded %>
    <%= form.checkbox :notifications %>
    <%= form.label :notifications, "Enable notifications" %>
  </div>
</details>
```

Screen readers announce the [`<summary>`][summary-el] as a button with an
expanded or collapsed state. The user activates it with Enter or Space (on
desktop) or double-tap (on mobile).

[summary-el]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/summary

Browsers add a default disclosure triangle to the `<summary>`. If it does not
fit the design, CSS can remove it with `list-style: none`:

```css
summary {
  list-style: none;
}
```

The expanded or collapsed state remains accessible to screen readers regardless
of whether the triangle is visible.

WARNING: `<summary>` is itself an interactive control, so do not nest links,
buttons, or other interactive elements inside it. Do not wrap `<details>` in a
`<legend>` either: the markup is invalid (`<details>` is not phrasing content),
and the trigger then becomes part of the fieldset's group label, which screen
readers re-announce alongside every control in the group.

#### Exclusive Accordions with `name`

When multiple `<details>` elements share the same [`name`][details-name]
attribute, they form an exclusive group: opening one automatically closes the
others. This creates an accordion without any JavaScript:

[details-name]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/details#name

```html+erb
<details name="faq">
  <summary>How do I reset my password?</summary>
  <p>Open the login page and follow the "Forgot password" link.</p>
</details>

<details name="faq">
  <summary>How do I change my email?</summary>
  <p>Go to Settings > Account > Email.</p>
</details>

<details name="faq">
  <summary>How do I delete my account?</summary>
  <p>Contact support to request account deletion.</p>
</details>
```

### Dialogs

A common pattern in web applications is to show a confirmation prompt, a form,
or a settings panel in an overlay on top of the page. Often these are built with
a `<div>` positioned with CSS, toggled with JavaScript, and styled to look like
a modal. Visually this works, but for a screen reader user, nothing happened:
the "modal" opened silently, focus did not move into it, and the user can still
navigate to elements behind it. There is no indication that a dialog appeared.

The [`<dialog>`][dialog-el] element solves this. When a screen reader enters a
`<dialog>`, it creates a **bounded context**: browse mode is limited to the
dialog's content, and the user cannot navigate outside it with arrow keys or
quick navigation. The screen reader announces the dialog's role, name, and
description immediately, so the user knows where they are and why.

[dialog-el]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dialog

#### Why Focus Trapping Matters

When a modal dialog opens, the user should not be able to interact with the page
behind it. This is called **focus trapping**: focus is confined to the dialog,
so no element outside it can receive focus by any means. Tab and Shift+Tab cycle
only through focusable elements inside the dialog, and clicks or programmatic
focus on outside elements are blocked too.

But trapping focus is only part of the story. Without additional measures, a
screen reader user in browse mode can still arrow past the dialog into the page
behind it. On mobile, the user can still tap elements outside the dialog. Simply
preventing focus from leaving is not enough.

The native `<dialog>` element handles this correctly. [`showModal()`][showModal]
promotes the dialog into the browser's top layer and marks the rest of the
document as blocked: the content behind it becomes non-focusable,
non-interactive for touch and click, and hidden from screen readers. This is the
only reliable way to fully contain focus across all platforms and input methods.

Building a custom modal without `<dialog>` requires replicating all of that by
hand: applying the [`inert`][inert-attr] attribute to every sibling of the
modal, managing focus restoration, handling Escape key dismissal, and preventing
scrolling, all of which the native element provides for free.

[showModal]: https://developer.mozilla.org/en-US/docs/Web/API/HTMLDialogElement/showModal

#### Modal Dialogs with `showModal()`

Use `aria-labelledby` to name the dialog after its heading and
`aria-describedby` to associate its description. The [Invoker Commands
API][invoker-commands] lets developers open and close dialogs declaratively with
`commandfor` and `command`, without any JavaScript:

[invoker-commands]: https://developer.mozilla.org/en-US/docs/Web/API/Invoker_Commands_API

```html+erb
<button commandfor="confirm-dialog" command="show-modal">Delete</button>

<dialog id="confirm-dialog"
    aria-labelledby="confirm-dialog-title"
    aria-describedby="confirm-dialog-description">
  <h2 id="confirm-dialog-title">Are you sure?</h2>
  <p id="confirm-dialog-description">This action cannot be undone.</p>
  <form method="dialog">
    <button commandfor="confirm-dialog" command="close" value="cancel">
      Cancel
    </button>
    <button value="confirm">Confirm</button>
  </form>
</dialog>
```

When the dialog opens, the screen reader announces: "Are you sure?, dialog, This
action cannot be undone." The user immediately knows what the dialog is about.
Because the dialog forms its own bounded context, its heading hierarchy can
start fresh from a level that fits the design, often `<h2>`, regardless of the
surrounding page outline.

The `commandfor` attribute specifies the target element's ID, and `command`
specifies the action (`show-modal`, `close`, `show-popover`, `hide-popover`,
`toggle-popover`).

When opened with `showModal()`, the `<dialog>`:

* Announces its name and description to screen readers.
* Limits browse mode to the dialog content (the user cannot arrow outside).
* **Focuses the first focusable element** inside the dialog. The
  [`autofocus`][autofocus-attr] attribute controls which element receives focus,
  and the right target depends on the dialog's purpose. For a destructive
  confirmation, focus the **least destructive** option (typically Cancel) so an
  accidental Enter does not cause harm. For a brief form the user just opened on
  purpose, focus the first field so they can start typing. For a long or
  unexpected message, focus the dialog or its heading so the user has a chance
  to read the content before reaching the controls. If no element has
  `autofocus`, focus goes to the first focusable element in DOM order.
* Traps focus (Tab and Shift+Tab cycle only through elements inside it).
* Makes all content outside the dialog inert (not focusable, not interactive,
  not visible to screen readers).
* Closes when the user presses Escape.
* **Returns focus to the element that opened it** when closed. This is critical:
  imagine browsing a menu of items, opening a dialog to see the details of one,
  and then closing it. If focus did not return, the user would have to navigate
  through the entire page again to find where they were. The native `<dialog>`
  handles this automatically.

NOTE: Invoker Commands are supported in Chrome 135+, Firefox 144+, and Safari
26.2+. For older browsers, use the [invokers-polyfill] package.

[invokers-polyfill]: https://github.com/keithamus/invokers-polyfill

#### Light Dismiss with `closedby`

By default, modal dialogs close only via Escape or an explicit action. The
[`closedby`][closedby-attr] attribute adds the ability to close by clicking
outside the dialog (light dismiss):

[autofocus-attr]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/autofocus
[closedby-attr]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dialog#closedby

```html
<dialog closedby="any">
  <!-- Closes on Escape, clicking outside, or explicit close -->
</dialog>
```

| Value | Behavior |
|-------|----------|
| `"closerequest"` | Closes on Escape or platform gesture (default for modals) |
| `"any"` | Also closes when clicking outside (light dismiss) |
| `"none"` | Only closes via JavaScript `dialog.close()` |

NOTE: The `closedby` attribute is supported in Chrome 134+ and Firefox 141+.
Until Safari ships it, use the [dialog-closedby-polyfill] package for
cross-browser support.

[dialog-closedby-polyfill]: https://github.com/tak-dcxi/dialog-closedby-polyfill

#### Styling the Backdrop and Animating Dialogs

Modal dialogs render a [`::backdrop`][css-backdrop] pseudo-element behind them,
covering the entire viewport. It can be styled to dim the page:

[css-backdrop]: https://developer.mozilla.org/en-US/docs/Web/CSS/::backdrop

```css
dialog::backdrop {
  background-color: rgb(0 0 0 / 40%);
}
```

To animate the dialog opening and closing, use CSS transitions with
[`@starting-style`][starting-style] to define the initial state. This enables a
smooth transition from `display: none` to visible:

[starting-style]: https://developer.mozilla.org/en-US/docs/Web/CSS/@starting-style

```css
@media (prefers-reduced-motion: no-preference) {
  dialog {
    opacity: 0;
    transition: opacity 0.3s, display 0.3s allow-discrete,
      overlay 0.3s allow-discrete;
  }

  dialog[open] {
    opacity: 1;
  }

  @starting-style {
    dialog[open] {
      opacity: 0;
    }
  }

  dialog::backdrop {
    transition: background-color 0.3s, display 0.3s allow-discrete,
      overlay 0.3s allow-discrete;
  }

  @starting-style {
    dialog[open]::backdrop {
      background-color: transparent;
    }
  }
}
```

The animations are wrapped in `prefers-reduced-motion: no-preference`, so they
only apply for users who have not requested reduced motion. The `display` and
`overlay` properties need `allow-discrete` so the dialog stays visible
throughout the animation instead of disappearing immediately.

### Popovers

The [Popover API](https://developer.mozilla.org/en-US/docs/Web/API/Popover_API)
provides non-modal overlays that render in the top layer. Unlike modal dialogs,
popovers do not trap focus or make the rest of the page inert: the user can
still interact with the page behind them. They close automatically when the user
clicks outside or presses Escape (light dismiss).

Use [`popovertarget`][popovertarget] on a button to toggle a popover without
JavaScript:

[popovertarget]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/button#popovertarget

```html+erb
<button popovertarget="notifications">
  Notifications
</button>

<div id="notifications" popover>
  <p>You have 3 new messages.</p>
</div>
```

Use [`popovertargetaction`][popovertargetaction] to explicitly show or hide
instead of toggling:

[popovertargetaction]: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/button#popovertargetaction

```html
<button popovertarget="menu" popovertargetaction="show">Open</button>
<button popovertarget="menu" popovertargetaction="hide">Close</button>
```

#### Positioning Popovers with CSS Anchor Positioning

Popovers render in the top layer, which detaches them from the normal document
flow and leaves them without a natural position. [CSS anchor
positioning][anchor-positioning] lets the browser tether a popover to its
trigger without JavaScript: declare the trigger as an anchor with `anchor-name`,
reference it from the popover with `position-anchor`, and pick a side with
`position-area`. The browser keeps the popover tethered even when the trigger
moves, wraps, or scrolls.

[anchor-positioning]: https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_anchor_positioning

Tethering the `notifications` popover from the example above to its trigger only
takes CSS:

```css
[popovertarget="notifications"] {
  anchor-name: --notifications;
}

#notifications {
  position-anchor: --notifications;
  position-area: bottom span-right;
  margin-top: 0.5rem;
  position-try-fallbacks: top span-right, bottom span-left, top span-left;
}
```

`position-area: bottom span-right` places the popover below the trigger, aligned
to its right edge. `position-try-fallbacks` lists alternative placements the
browser can pick when the default would overflow the viewport, so the popover
stays visible on narrow screens without custom logic.

The `::backdrop` pseudo-element and `@starting-style` animations demonstrated in
[Styling the Backdrop and Animating
Dialogs](#styling-the-backdrop-and-animating-dialogs) work the same way for
popovers. Target `[popover]` instead of `dialog` in those rules.

NOTE: Anchor positioning is supported in Chrome/Edge 125+, Safari 26+, and
Firefox 147+. Older browsers ignore the properties and fall back to whatever
static CSS positioning the popover has (or none, in which case the browser
positions it with its default top-layer placement). Design the fallback so the
popover is still usable, provide a polyfill such as
[@oddbird/css-anchor-positioning][anchor-polyfill], or gate the anchored layout
behind `@supports (anchor-name: --x)` when the design depends on it.

[anchor-polyfill]: https://github.com/oddbird/css-anchor-positioning

#### When to Use Popovers vs. Dialogs

The choice depends on how much the overlay should isolate the user from the rest
of the page:

| Pattern | Element | Focus trapped? | Page inert? | Browse mode bounded? |
|---------|---------|----------------|-------------|----------------------|
| **Tooltip or simple overlay** | `<div popover>` | No | No | No |
| **Menu or picker** | `<dialog popover>` | No | No | Yes |
| **Confirmation or form** | `<dialog>` with `showModal()` | Yes | Yes | Yes |

A plain `<div popover>` is just content that appears and disappears. Screen
readers announce the content but do not enter a special mode, so the user can
navigate away freely. Use this for tooltips, notifications, or simple dropdowns.

A `<dialog popover>` combines dialog semantics with popover behavior: the screen
reader enters a bounded dialog context (announcing the role and limiting browse
mode to the dialog content), but there is no focus trap and the rest of the page
remains interactive. Use this for menus and pickers where the user should be
aware they are in a distinct context:

```html+erb
<button popovertarget="user-menu">
  <%= image_tag "icons/profile.svg", alt: "" %>
  Account
</button>

<dialog id="user-menu" popover aria-label="Account menu">
  <nav>
    <ul>
      <li><%= link_to "Profile", profile_path %></li>
      <li><%= link_to "Settings", settings_path %></li>
      <li><%= button_to "Sign out", session_path, method: :delete %></li>
    </ul>
  </nav>
</dialog>
```

A `<dialog>` with `showModal()` is for content that demands the user's full
attention: confirmations, forms, critical decisions. The page behind it becomes
inert and focus is fully trapped, as described in the sections above.

### Tooltips and Content on Hover

Tooltips and similar content that appears on hover or focus have limitations
that are easy to miss:

* Touch devices have no hover state, so the content never appears.
* Keyboard users cannot hover either; they can only trigger focus, and revealing
  new content solely on focus risks the same context-change problems covered in
  [Avoiding Surprises on Focus and
  Input](#avoiding-surprises-on-focus-and-input).
* The HTML `title` attribute fails all of the requirements below and should not
  carry information users need.

When content does appear on hover or focus, [WCAG 1.4.13 Content on Hover or
Focus][wcag-content-on-hover] requires it to be:

[wcag-content-on-hover]: https://www.w3.org/WAI/WCAG22/Understanding/content-on-hover-or-focus.html

* **Dismissible** without moving the pointer or focus (for example, pressing
  Escape closes the content).
* **Hoverable** so the pointer can move onto the content without it
  disappearing.
* **Persistent** until the trigger is removed, focus moves away, or the user
  dismisses it.

Meeting all three requirements for a hover-driven tooltip takes careful
JavaScript. For most tooltip-like patterns, a toggle controlled by a real click
(or Enter/Space) is simpler and more accessible. A `<details>` element or a
`<div popover>` opened by a button meets all three requirements without any
custom JavaScript:

```html+erb
<button popovertarget="price-help">
  Why do we ask for this?
</button>
<div id="price-help" popover>
  <p>We use the total to estimate shipping. We never share this data.</p>
</div>
```

Users activate the button explicitly, the popover stays until they dismiss it,
and Escape closes it. Prefer patterns like this over hover-only tooltips
whenever the information matters.

Styling
-------

CSS decisions have a direct impact on accessibility. Focus indicators guide
keyboard users, hit areas determine reachability, colors set readability, layout
has to survive zoom and text resize, and user preferences communicated by the
operating system only take effect when the stylesheet respects them.

### Focus Indicators

Keyboard users locate themselves on the page through the focus indicator, the
ring the browser draws around whatever element they would activate next.
Removing it leaves them with no way to tell where they are ([WCAG 2.4.7 Focus
Visible][wcag-focus-visible]), so the indicator is non-negotiable. Custom styles
are fine, but making the indicator disappear is not.

[wcag-focus-visible]: https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html

The indicator also has to contrast at least 3:1 against any background it sits
on ([WCAG 1.4.11 Non-text Contrast][wcag-non-text-contrast]), and on pages that
mix light and dark surfaces a single-color ring tends to fail that threshold
somewhere. A two-color, two-ring indicator solves the problem in one declaration
by stacking four `box-shadow` layers (background, foreground, background,
foreground) so the ring stays visible against any surface the page paints behind
it:

```css
:focus-visible {
  outline: none;
  box-shadow:
    0 0 0 0.2rem var(--background, Canvas),
    0 0 0 0.4rem currentColor,
    0 0 0 0.6rem var(--background, Canvas),
    0 0 0 0.8rem hsl(from currentColor calc(h + 180) s l);
}

@media (forced-colors: active) {
  :focus-visible {
    box-shadow: none;
    outline: 0.2rem solid LinkText;
    outline-offset: 0.2rem;
  }
}
```

The inner ring uses `currentColor`, so it inherits the element's text color and
adapts automatically to light and dark themes. The outer ring is generated with
[relative color syntax][relative-color]: `hsl(from currentColor calc(h + 180) s
l)` rotates the hue by 180 degrees, producing a complementary tone that
contrasts against the same palette the rest of the page already uses. The two
rings are separated by gaps that match the page background, drawn with
`var(--background, Canvas)`. If the design system defines a `--background`
token, the gap follows it; otherwise the browser substitutes
[`Canvas`][system-colors], the system keyword for the user's content background.
The rule applies to every focusable element automatically: a bare
`:focus-visible` only matches elements that can receive keyboard focus, so
links, buttons, form controls, `<summary>`, and anything with `tabindex` are all
covered without enumerating them.

[relative-color]: https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_colors/Relative_colors
[system-colors]: https://developer.mozilla.org/en-US/docs/Web/CSS/system-color

The [`:focus-visible`][focus-visible] pseudo-class itself only triggers during
keyboard navigation, so mouse users keep the cleaner appearance the browser
gives clicks while keyboard users see the full indicator. Forced colors mode
discards `box-shadow` declarations to enforce the user's palette, so the
`forced-colors` block rebuilds the indicator with `outline` and the
[`LinkText`][system-colors] system keyword, guaranteeing visibility in High
Contrast Mode.

The same indicator can also reflect focus on a wrapper instead of on the focused
control. The [`:focus-within`][focus-within] pseudo-class matches an element
whenever any descendant is focused, so a card, fieldset, or table row can
highlight while one of its controls has focus:

[focus-within]: https://developer.mozilla.org/en-US/docs/Web/CSS/:focus-within

```css
fieldset:focus-within {
  outline: 2px solid currentColor;
  outline-offset: 4px;
}
```

The control's own `:focus-visible` indicator stays in place inside the wrapper,
so the keyboard user still sees exactly which control has focus within the
highlighted region.

A visible focus ring is not enough if another element hides it. Sticky or fixed
headers, footers, and floating toolbars commonly sit on top of the focused
element when the user tabs into content behind them ([WCAG 2.4.11 Focus Not
Obscured (Minimum)][wcag-focus-not-obscured-min]). Reserve scroll space for
these overlays with [`scroll-margin`][scroll-margin] on focusable elements, or
with [`scroll-padding`][scroll-padding] on the scroll container, so the browser
keeps the focused element in view:

[wcag-focus-not-obscured-min]: https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html
[scroll-margin]: https://developer.mozilla.org/en-US/docs/Web/CSS/scroll-margin
[scroll-padding]: https://developer.mozilla.org/en-US/docs/Web/CSS/scroll-padding

```css
:root {
  scroll-padding-block-start: 4rem; /* height of the sticky header */
  scroll-padding-block-end: 3rem;   /* height of a sticky footer */
}
```

### Target Size

Interactive controls need a large enough hit area for several kinds of users:
anyone tapping with a finger, anyone with low motor precision such as a head
pointer or eye-tracker user, anyone working on a small screen, and blind users
of a mobile screen reader who locate controls by sliding a finger across the
screen and cannot see where they are aiming.

[WCAG 2.5.8 Target Size (Minimum)][wcag-target-size] sets the conformant
baseline at **24 by 24 CSS pixels** for non-inline interactive targets. Three
exceptions apply:

* Inline links inside a sentence, where the size is constrained by the
  line-height of the surrounding text.
* Native controls left at their browser default size.
* Targets that have at least 24 CSS pixels of clear space around them, so that a
  24 px diameter circle centered on each does not intersect another.

Padding is the simplest way to reach the baseline without changing the visual
size of the control. Padding extends the interactive area, while margin does
not, so prefer padding when the goal is a larger hit area:

```css
.icon-button {
  padding: 0.5rem;
}
```

When padding would shift the surrounding layout, a transparent pseudo-element
extends the hit area without changing the visual size. Keep the parent
positioned so the pseudo-element anchors correctly:

```css
.icon-button {
  position: relative;
}

.icon-button::before {
  content: "";
  position: absolute;
  inline-size: 24px;
  block-size: 24px;
  top: 50%;
  left: 50%;
  translate: -50% -50%;
}
```

24 px is the conformant minimum, not a target size that suits every context.
[WCAG 2.5.5 Target Size (Enhanced)][wcag-target-size-enhanced] raises the bar to
**44 by 44 CSS pixels** at Level AAA, which is the right starting point for
primary controls on touch interfaces and for any flow that runs under stress or
fatigue. The practical pattern is to bake size variants into the design system
(small, medium, large, each conformant) and let each context pick what suits it,
rather than forcing one number across the entire interface.

[wcag-target-size-enhanced]: https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html

WARNING: Avoid using `@media (any-pointer: coarse)` to grow targets only on
touchscreens. Many devices today are multimodal: laptops and desktops with
touchscreens accept finger input, trackpad input, and a connected mouse all in
the same session, and a phone may have a Bluetooth mouse or stylus connected.
Motor differences can also make a mouse user need the same room a touchscreen
user does. Conditional sizing assumes one input method per session, which no
longer matches how people use their devices.

### Visual Order

A common shortcut for arranging items inside a flex or grid layout is to leave
the HTML as it comes from the database and rely on CSS to put the right items
first visually. [`order`][css-order] promotes some items, [`flex-direction:
row-reverse`][flex-direction] (or `column-reverse`) flips the main axis,
[`grid-auto-flow: dense`][grid-auto-flow] backfills empty cells from items
declared later, [`grid-template-areas`][grid-template-areas] and explicit
grid-line placements (`grid-column`, `grid-row`) can move items anywhere in the
visual grid regardless of source order, and `position: absolute` takes an item
out of flow entirely. Visually they all work.

[css-order]: https://developer.mozilla.org/en-US/docs/Web/CSS/order
[flex-direction]: https://developer.mozilla.org/en-US/docs/Web/CSS/flex-direction
[grid-auto-flow]: https://developer.mozilla.org/en-US/docs/Web/CSS/grid-auto-flow
[grid-template-areas]: https://developer.mozilla.org/en-US/docs/Web/CSS/grid-template-areas

Assistive technologies follow the HTML source instead, as covered in [How Screen
Readers Work](#how-screen-readers-work). When the source order and the visual
order disagree, a sighted user sees the page in one sequence, a screen reader
announces it in another, and a keyboard user tabs through it in a third. Each
audience follows its own arrangement, and only one of them matches the design
([WCAG 1.3.2 Meaningful Sequence][wcag-meaningful-sequence], [WCAG 2.4.3 Focus
Order][wcag-focus-order]).

[wcag-focus-order]: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html

Take a list of cards rendered straight from the database in insertion order
(oldest first), with a CSS rule that promotes featured ones to the top of the
grid:

```html+erb
<%# app/views/cards/index.html.erb %>
<div class="cards">
  <%= render @cards %>
</div>
```

```css
.card.featured {
  order: -1;
}
```

A sighted user sees the featured cards first. A blind user hears the oldest
non-featured card first, because that is what the HTML lists first. A keyboard
user reaches the same oldest card on the first Tab. The featured cards are
effectively buried for everyone who cannot see the layout.

When the order carries meaning, reorder the source. In Rails that almost always
means sorting the collection in the controller or the model so the HTML arrives
in the same order users will see it:

```ruby
# app/controllers/cards_controller.rb
class CardsController < ApplicationController
  def index
    @cards = Card.order(featured: :desc, created_at: :desc)
  end
end
```

CSS reordering remains safe when the change is purely cosmetic and conveys no
information: flipping a row under `:dir(rtl)`, arranging decorative shapes, or
mirroring a layout for a logo wall. The test is whether anyone could deduce
intent from the order. If they could, every audience needs the same order.

Directional language has the same problem in prose. Phrases like "see the panel
below", "use the column on the right", or "click the button at the top of the
page" rely on visual location, which changes the moment the content reflows: a
screen reader user hears items linearly, a low-vision user at high zoom sees a
single column, a right-to-left translation flips left and right, a mobile layout
collapses everything ([WCAG 1.3.3 Sensory
Characteristics][wcag-sensory-characteristics]). Refer to content by its name
and link to it where possible:

[wcag-sensory-characteristics]: https://www.w3.org/WAI/WCAG22/Understanding/sensory-characteristics.html

* Avoid: "See the form below." Prefer: "Refer to the **Sign-up form**" (linked
  when possible).
* Avoid: "Use the navigation on the left." Prefer: "Use the primary navigation."
* Avoid: "Click the button at the bottom right." Prefer: "**Save** the form."

NOTE: Responsive layouts that genuinely require a different visual order at
different breakpoints have no perfect solution: there is no way to ship one HTML
source that matches every breakpoint's reading order. Building mobile-first
reduces the risk in practice, since a source order that works on a single column
tends to translate cleanly to wider layouts. When a breakpoint truly cannot
avoid a reorder, test the result at that width with a keyboard and a screen
reader to confirm the experience is still understandable.

### Horizontal Scrolling

Wide tables, image rails, and "card carousels" are often forced into a
horizontal-scroll container so they fit on narrow viewports. The pattern looks
compact but creates barriers for several audiences at once.

The starting point is [WCAG 1.4.10 Reflow][wcag-reflow]: page content has to be
presented without requiring scroll in two directions at the same time, so that
users at high zoom can read the page in a single column. Data tables and other
essentially two-dimensional content are the named exception, and the burden
falls on the rest of the layout to reflow rather than scroll sideways.

[wcag-reflow]: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html

The barriers compound for keyboard, voice, and pointer users. Arrow keys do not
scroll a non-focusable container, so the only way to expose content hidden to
the side is to Tab into a focusable control inside the rail until the browser
auto-scrolls it into view. Non-interactive content (text, images, data without
an associated control) becomes unreachable by keyboard alone ([WCAG 2.1.1
Keyboard][wcag-keyboard]). Voice control users have to identify the rail by
name, find a way to scroll it without a clearly named scroll affordance, and
then activate the target inside it. On mobile, horizontal swipes inside the rail
compete with the platform's own swipe gestures for navigation, and the rail can
be visually mistaken for a carousel that the user already knows to skip.

The accessible answer is rarely "make the horizontal-scroll container better."
Most of the time it is to rework the information architecture: stack the items
vertically, paginate them, surface only the most relevant ones with a link to a
fuller view, or render a wide table as a real `<table>` and let the user reflow
it at the platform's preferred zoom. Reach for horizontal scrolling only when
the data is genuinely two-dimensional and reflowing it would lose meaning, and
even then keep the focusable elements inside the container reachable during
keyboard navigation.

### Color

Ensure sufficient contrast between text and backgrounds ([WCAG 1.4.3 Contrast
(Minimum)][wcag-contrast], [WCAG 1.4.11 Non-text
Contrast][wcag-non-text-contrast]):

* **Normal text**: 4.5:1 minimum (Level AA).
* **Large text** (18pt+, or 14pt bold+): 3:1 minimum.
* **UI components** (borders, icons, focus indicators): 3:1 minimum.

Always declare `color` and `background-color` together. Browser defaults are not
guaranteed because users can override them in their browser settings or
extensions, and a stylesheet that sets only one of the two can produce text that
is unreadable against a customized background:

```css
body {
  color: #111;
  background-color: #fff;
}
```

Contrast is only half of the job. Color is a presentation layer, not a meaning
layer, so it cannot be the only channel that communicates state or
differentiates options. Users with color vision deficiencies cannot reliably
distinguish red from green form validation icons, and a "required" field marked
only by a red label disappears entirely for a screen reader. Pair color with a
second signal: text, an icon with a label, an underline, or a pattern ([WCAG
1.4.1 Use of Color][wcag-use-of-color]):

```html+erb
<%# Avoid: only the red color of the label marks this field as required. %>
<%= form.label :email_address, class: "required" %>
<%= form.email_field :email_address %>

<%# Prefer: the word "required" sits alongside the visual cue,
    so the requirement also reaches users who cannot perceive the color. %>
<%= form.label :email_address, "Email address (required)" %>
<%= form.email_field :email_address, required: true %>
```

The same principle applies to links inside running text. A link that differs
from the surrounding text only in color is invisible to color-blind users and to
anyone reading in a context that strips color (printed pages, certain forced
palettes), so the underline carries the cue the color cannot. Italic or bold
treatment alone is technically allowed as the non-color cue, but in prose both
already signal other things (emphasis, citation), so a user has no way to tell
that a particular italic word is a link rather than an emphasized phrase.
Underline is the convention precisely because it does not collide with prose
semantics:

```css
p a {
  color: #0044cc;
  text-decoration: underline;
}
```

TIP: The [axe browser extension](https://www.deque.com/axe/devtools/extension/),
Chrome DevTools, and Firefox Accessibility Inspector can all check contrast
ratios directly on the page. The [WebAIM Contrast
Checker](https://webaim.org/resources/contrastchecker/) is a useful standalone
tool.

### Zoom and Text Resize

Users with low vision routinely zoom pages to 200 percent or beyond using
browser zoom or the operating system's text-size setting. A layout that breaks
at this zoom level (text clipped, controls overlapping, horizontal scrolling on
narrow viewports) cuts off these users ([WCAG 1.4.4 Resize Text][wcag-resize],
[WCAG 1.4.10 Reflow][wcag-reflow]).

[wcag-resize]: https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html

Two CSS habits keep layouts resilient at any zoom level:

* **Use relative units (`rem`, `em`, `%`) for font sizes, paddings, widths, and
  media query breakpoints.** Absolute units like `px` ignore the user's
  preferred base font size, so a layout built on px values does not honor a
  reader's choice to enlarge default text in their browser or operating system.
  The [`ch`][ch-unit] unit (one `ch` equals the width of the `0` character in
  the current font) is especially useful for capping the width of prose: setting
  `max-width: 65ch` on `<p>`, `<li>`, or article bodies keeps lines at a
  comfortable reading length regardless of font size.
* **Let containers grow with their content.** Avoid fixed pixel heights on text
  containers, and allow wrapping rather than clipping overflowing text.

[ch-unit]: https://developer.mozilla.org/en-US/docs/Web/CSS/length#ch

Leave the root `font-size` alone, or set it to `100%` to make the inheritance
explicit, so the page picks up whatever the user configured in their browser or
operating system. Tricks that reset it for math convenience, like `html {
font-size: 62.5% }`, force every reader to bump their preferred size by 60
percent just to land back on what they originally chose. Form controls escape
that inheritance by default and ship with browser-fixed typography that ignores
the body cascade, so add one rule to bring them back in line:

```css
select, textarea, input, button {
  font: inherit;
}
```

A page must also keep working when users override the spacing of running text
via a user stylesheet ([WCAG 1.4.12 Text Spacing][wcag-text-spacing]). The
criterion sets concrete minimums that the layout has to survive without losing
content or functionality: line height of at least 1.5 times the font size,
spacing after paragraphs of at least 2 times the font size, letter spacing of at
least 0.12 times the font size, and word spacing of at least 0.16 times the font
size. Avoid rules like `line-height: 16px !important` or fixed container heights
that would clip enlarged text under those values.

[wcag-text-spacing]: https://www.w3.org/WAI/WCAG22/Understanding/text-spacing.html

The viewport meta tag carries the same responsibility on mobile: it must not
disable pinch-to-zoom. The Rails default layout already ships the correct value:

```html
<meta name="viewport" content="width=device-width,initial-scale=1">
```

Do not add `user-scalable=no` or `maximum-scale=1` to that content string: both
prevent users from zooming the page on touch devices ([WCAG 1.4.4 Resize
Text][wcag-resize], per the [W3C ACT rule for meta viewport][act-viewport]).

[act-viewport]: https://www.w3.org/WAI/standards-guidelines/act/rules/b4f0c3/

Content also has to work in both portrait and landscape. Some users have their
device fixed in one position by a wheelchair mount, a desk stand, or a strap, so
a layout that hides content or refuses to render outside a single orientation
locks them out ([WCAG 1.3.4 Orientation][wcag-orientation]). The criterion only
allows restriction when one is essential to the experience, like a piano
keyboard or a bank check deposit camera. Avoid CSS rules that hide content under
a specific orientation media query, and do not call `screen.orientation.lock()`:

[wcag-orientation]: https://www.w3.org/WAI/WCAG22/Understanding/orientation.html

```css
/* Avoid: locks the main content out of landscape entirely. */
@media (orientation: landscape) {
  .main-content { display: none; }
}
```

```js
// Avoid: forces portrait, even for users with the device mounted sideways.
screen.orientation.lock("portrait")
```

### Respecting User Preferences

Operating systems let users set preferences like "reduce motion" or "high
contrast". Browsers expose these preferences through CSS media queries. Honor
them to keep the application comfortable for users who have opted in.

The one that comes up most in a web application is
[`prefers-reduced-motion`][prefers-reduced-motion]. Animation is a barrier for
users with vestibular disorders or attention differences, which is why
interaction-driven animations should respect a user's request to reduce motion
([WCAG 2.3.3 Animation from Interactions][wcag-animation-from-interactions]).
Wrap every animation and transition so it only runs when the user has not
requested reduced motion:

```css
@media (prefers-reduced-motion: no-preference) {
  .reveal {
    animation: fade-in 0.3s;
  }
}
```

The [modal dialog animations](#styling-the-backdrop-and-animating-dialogs) use
the same pattern. Wrapping each animation individually is opt-in and
intentional: it forces a conscious decision per effect, and any motion that has
a functional role (a progress indicator, a state change cue) can stay outside
the guard when appropriate. Reduced motion targets movement specifically, so
transitions on color, opacity, and cross-fades can stay outside the guard as
well. What users in this group ask to avoid is translation, rotation, scale, and
large screen movement, not every animation on the page.

A more aggressive fallback appears in many templates that globally cancel
animation and transition durations with `!important` under
`prefers-reduced-motion: reduce`. It works as a safety net for animations that
were not wrapped, but it hides intent and overrides declarations it was not
meant to touch. Prefer the guard above for new code and reach for the global
override only to patch legacy animations that cannot be updated in place.

[prefers-reduced-motion]: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion
[wcag-animation-from-interactions]: https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html

Other media queries worth knowing:

* [`prefers-color-scheme`][prefers-color-scheme]: user preference for light or
  dark UI. Declare the supported schemes with [`color-scheme`][color-scheme] on
  `:root` so native controls, scrollbars, and form widgets follow the user's
  setting, and drive the rest of the colors from CSS custom properties so both
  themes share the same structure:

  ```css
  :root {
    color-scheme: light dark;
    --background: white;
    --text: #111;
  }

  @media (prefers-color-scheme: dark) {
    :root {
      --background: #111;
      --text: #f5f5f5;
    }
  }

  body {
    background: var(--background);
    color: var(--text);
  }
  ```

* [`prefers-contrast`][prefers-contrast]: user request for more or less
  contrast. Swap colors that sit close together for ones with a clearer ratio:

  ```css
  @media (prefers-contrast: more) {
    a {
      color: #00338d;
      text-decoration-thickness: 2px;
    }
  }
  ```

* [`forced-colors`][forced-colors]: the operating system is enforcing its own
  palette, as happens with Windows High Contrast Mode. The browser replaces most
  colors with the system palette, so fixed values like `border-color: #4A90D9`
  may be ignored. This is exactly why the focus rule above uses `currentColor`:
  the outline follows the user's text color and stays visible through the
  override. The same principle applies to any UI surface with a branded color;
  reach for `currentColor` or [system color keywords][system-colors] when the
  element needs to survive a forced palette.

  When the design relies on CSS custom properties as design tokens, redeclare
  those tokens inside the same query so they map to system colors during High
  Contrast Mode:

  ```css
  :root {
    --link-color: #0044cc;
    --button-bg: #f5f5f5;
    --button-text: #111;
  }

  @media (forced-colors: active) {
    :root {
      --link-color: LinkText;
      --button-bg: ButtonFace;
      --button-text: ButtonText;
    }
  }
  ```

  Components built on these tokens keep working under a forced palette without
  any per-component changes.

[prefers-color-scheme]: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-color-scheme
[color-scheme]: https://developer.mozilla.org/en-US/docs/Web/CSS/color-scheme
[prefers-contrast]: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-contrast
[forced-colors]: https://developer.mozilla.org/en-US/docs/Web/CSS/@media/forced-colors

### Browser Affordances

The browser ships its own UI for the cursor and the scrollbar, both of which the
user can customize at the operating system level: enlarged or high-contrast
cursors for low vision, wider scrollbars or system-themed colors for motor and
contrast accommodations. CSS lets a stylesheet override both, but those
overrides remove the very settings the user opted into.

A custom cursor loaded with `cursor: url(...)` rarely scales or contrasts to
match what the user configured for low vision use, and on slow connections it
adds a network round trip before the pointer can render. Restyling the scrollbar
with `scrollbar-color`, `scrollbar-width`, or `::-webkit-scrollbar` runs into a
similar problem: the customized scrollbar tends to disappear under Forced Colors
and Increased Contrast modes, and replacing it shifts [WCAG 1.4.11 Non-text
Contrast][wcag-non-text-contrast] onto the application that the browser was
already handling. Leave both alone unless there is a concrete user-facing reason
that outweighs those costs.

### ARIA State Selectors in CSS

As shown in the [`aria-current` example](#indicating-the-current-page), ARIA
attributes can be used as CSS selectors. This avoids maintaining separate CSS
classes for state and keeps the ARIA attribute as the single source of truth for
both screen readers and visual styles:

```css
[aria-invalid="true"] {
  border-color: #d32f2f;
}

[aria-pressed="true"] {
  background-color: #e0e0e0;
}
```

A related anti-pattern is toggling a CSS class like `.is-open` or `.active` to
represent state and ignoring the ARIA attribute altogether, sometimes through a
generic "toggle class" Stimulus controller. When a class is the only signal,
screen readers hear nothing change: the element looks different on screen, but
it carries the same role, name, and state in the accessibility tree as it did
before. Treat the ARIA attribute (`aria-pressed`, `aria-current`,
`aria-invalid`) as the state, and style from it. Toggling the attribute updates
both the accessibility tree and the visual design in one step.

Turbo
-----

[Turbo](https://turbo.hotwired.dev/handbook/introduction) updates the page
without full reloads, which creates a fundamental challenge for assistive
technologies. In a traditional navigation, the browser loads a new page,
announces the new title to screen readers, and starts reading from the top. With
Turbo, none of this happens: Turbo replaces content silently, focus moves to
`document.body`, and the screen reader says nothing. The user performed an
action, something changed, but nothing tells them so. The app has to signal it:

* **Moving focus** to the new content, so the screen reader announces it as the
  user lands there.
* **Announcing the change** through a live region, when moving focus would be
  disruptive.

### Moving Focus with `autofocus`

Use the [`autofocus`][autofocus-attr] attribute to direct focus to the most
meaningful element after Turbo navigates to a new page or updates content in
place. When the target is not normally focusable (like a heading), add
`tabindex="-1"` to make it focusable without adding it to the Tab order.

The element to focus depends on what Turbo replaced.

#### Turbo Drive

[Turbo Drive][turbo-drive] navigations replace the entire `<body>`. Place
`autofocus` on the `<h1>` of each page so the screen reader announces where the
user is:

[turbo-drive]: https://turbo.hotwired.dev/handbook/drive

```html+erb
<%# app/views/articles/show.html.erb %>
<h1 tabindex="-1" autofocus><%= @article.title %></h1>
```

This pattern has a subtle problem. Whenever the `<body>` is replaced, the `<h1>`
is re-rendered and `autofocus` re-evaluates, hijacking focus from wherever the
user was. This breaks two common flows:

* **Form submissions that fail with [422 Unprocessable Content][422]**: Turbo
  re-renders the form to show errors, but focus jumps to the `<h1>` instead of
  the invalid field.
* **Sort and filter links**: the user activates a control, the page re-renders,
  and focus is stolen from where the user was interacting.

The solution is to use [Turbo page refreshes with
morphing][turbo-page-refreshes] for same-URL updates. With morphing, the `<h1>`
persists as the same DOM element and `autofocus` does not re-evaluate,
preserving the user's focus naturally.

Enable morphing in the layout with the
[`turbo_refreshes_with`][turbo_refreshes_with] helper. It uses
[`provide`][provide] internally, so it must be called **before** `yield :head`
in the layout:

[422]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/422
[turbo-page-refreshes]: https://turbo.hotwired.dev/handbook/page_refreshes
[turbo_refreshes_with]: https://rubydoc.info/gems/turbo-rails/Turbo%2FDriveHelper:turbo_refreshes_with
[provide]: https://api.rubyonrails.org/classes/ActionView/Helpers/CaptureHelper.html#method-i-provide

```html+erb
<%# app/views/layouts/application.html.erb %>
<% turbo_refreshes_with method: :morph, scroll: :preserve %>
<!DOCTYPE html>
<html lang="<%= I18n.locale %>">
  <head>
    <%= yield :head %>
    <%# ... %>
  </head>
  <%# ... %>
</html>
```

For links that update the same page with different query params (for example,
changing the sort column or applying a filter), add
`data-turbo-action="replace"`. Turbo treats these as page refreshes and applies
morphing:

```html+erb
<%= link_to "Email", team_members_path(sort_by: "email"), data: { turbo_action: "replace" } %>
```

With this setup, `autofocus` only moves focus on genuine navigations to a
different page, and interactions like sorting a table keep the user right where
they were.

NOTE: Turbo Drive can animate page transitions through the browser's [View
Transitions API][view-transitions] when the layout opts in with `<meta
name="view-transition" content="same-origin">`. Turbo checks
`prefers-reduced-motion` before running the animation and skips it when the user
has requested reduced motion, so the opt-in respects the same user preference
the rest of the styling should honor.

[view-transitions]: https://developer.mozilla.org/en-US/docs/Web/API/View_Transition_API

#### Turbo Frames

[Turbo Frames][turbo-frames] replace content within a frame. Lazy-loaded
sections, such as a comments thread that only loads when the user requests it,
are a common use case. These replacements do not move focus automatically, so
activating the link to show the content leaves the user with no signal that
anything happened.

Placing `autofocus` inside the replacement markup directs focus to the revealed
content once the frame updates. The [`turbo_frame_tag`][turbo_frame_tag] helper
renders the frame:

[turbo-frames]: https://turbo.hotwired.dev/handbook/frames
[turbo_frame_tag]: https://rubydoc.info/gems/turbo-rails/Turbo%2FFramesHelper:turbo_frame_tag

```html+erb
<%# app/views/articles/show.html.erb %>
<%= turbo_frame_tag "comments" do %>
  <%= link_to "Show comments", article_comments_path(@article) %>
<% end %>
```

```html+erb
<%# app/views/comments/index.html.erb %>
<%= turbo_frame_tag "comments" do %>
  <h2 tabindex="-1" autofocus><%= pluralize(@comments.size, "comment") %></h2>
  <%# list of comments %>
<% end %>
```

When the user activates the link, Turbo fetches the comments partial, swaps it
into the frame, and the `<h2>` with `autofocus` receives focus. The screen
reader announces "3 comments, heading level 2", leaving no doubt that the
content appeared.

#### Turbo Streams

[Turbo Streams][turbo-streams] can modify content anywhere on the page. When a
stream responds to a user action and the result should receive attention,
`autofocus` on the new element directs focus to the change:

[turbo-streams]: https://turbo.hotwired.dev/handbook/streams

```html+erb
<%= turbo_stream.prepend "tasks" do %>
  <div tabindex="-1" autofocus>
    <%= render @task %>
  </div>
<% end %>
```

Turbo Streams execute whenever they enter the DOM, so this works from any
response, including Turbo Frame responses.

WARNING: Never use `autofocus` on content that arrives via broadcasts or
real-time updates. Moving focus unexpectedly, while the user is in the middle of
typing or reading, is disruptive. Reserve `autofocus` for direct responses to
user-initiated actions.

### Announcing Changes without Moving Focus

Not every change should move focus. If content updates in the background (a
notification count, a status message, a filter result), moving focus would be
disruptive. But without focus moving, the screen reader says nothing ([WCAG
4.1.3 Status Messages][wcag-status-messages]).

This is where live regions become essential, as introduced in [Announcing
Dynamic Changes with `aria-live`](#announcing-dynamic-changes-with-aria-live).
Live regions have a critical requirement: the element must **already exist in
the DOM** before its content changes. If a live region is created at the same
time as its text, there is no "change" to detect and the screen reader says
nothing. This has direct consequences for how Turbo can interact with live
regions:

* **Turbo Drive navigations** replace the entire `<body>`. Most live regions are
  destroyed and recreated with their content already in place, so the screen
  reader does not announce them. For navigation feedback, use `autofocus`
  instead. The exception is the `role="alert"` pattern covered in [Flash
  Messages](#flash-messages).
* **Turbo Stream `replace` and `append`** create new DOM elements. A new element
  with `aria-live` is not an existing live region, so its content will not be
  announced. Only `update` (changing the content of an existing element)
  triggers a live region announcement.

Place the live region at the end of the `<body>`. Screen readers read content in
the order it appears in the HTML source, as covered in [How Screen Readers
Work](#how-screen-readers-work), so a live region at the top of the page would
sit in the middle of the normal reading flow. When a user arrows through the
page, or uses heading or landmark navigation, they would run into the region's
text even when no live announcement is happening. Putting it after the main
content keeps it out of the reading path while still letting the browser
dispatch announcements from it:

```html+erb
<%# app/views/layouts/application.html.erb %>
<body>
  <%# ... page content ... %>

  <div id="live_announcements" aria-live="polite" data-controller="announcements"></div>
</body>
```

Update its content with a Turbo Stream:

```html+erb
<%= turbo_stream.update "live_announcements", "Article was saved successfully." %>
```

The announcement text should not stay permanently. If the user navigates past it
later, they would hear an outdated message. A Stimulus controller can clear it
after a short delay, long enough for the screen reader to pick it up:

```js
// app/javascript/controllers/announcements_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  #timeout

  connect() {
    this.#observer.observe(this.element, { childList: true })
  }

  disconnect() {
    this.#observer.disconnect()
  }

  #observer = new MutationObserver(() => {
    if (this.element.textContent.trim()) {
      clearTimeout(this.#timeout)
      this.#timeout = setTimeout(() => this.element.textContent = "", 1000)
    }
  })
}
```

### Form Submitter State

While a form submission is in flight, Turbo adds the `disabled` attribute to the
submit button and removes it once the response arrives. This prevents duplicate
submissions, but it has the same accessibility drawbacks as any disabled control
(see [Disabling Controls Carefully](#disabling-controls-carefully)): the button
loses focus, screen readers stop announcing it, and low-contrast rules apply.

Turbo exposes `Turbo.config.forms.submitter` to change this behavior. Setting it
to `"aria-disabled"` tells Turbo to toggle `aria-disabled="true"` on the submit
button instead of `disabled`. The button stays focusable, screen readers keep
announcing it with the disabled state, and no focus is lost ([WCAG 4.1.2 Name,
Role, Value][wcag-name-role-value]):

```js
// app/javascript/application.js
Turbo.config.forms.submitter = "aria-disabled"
```

The default import of `turbo-rails` assigns `window.Turbo`, so `Turbo` is
available as a global in `application.js` without an extra import.

Pair this with a loading style so sighted users see that submission is in
progress, and with the [`data-turbo-submits-with`][turbo-submits-with] attribute
to change the button text while the request runs:

[turbo-submits-with]: https://turbo.hotwired.dev/reference/attributes

```html+erb
<%= form.submit "Save", data: { turbo_submits_with: "Saving..." } %>
```

```css
:is(button, input[type="submit"])[aria-disabled="true"] {
  opacity: 0.6;
  cursor: progress;
}
```

The result behaves the same as the default for users who click (the button
rejects a second press), while keyboard and screen reader users keep track of
where they are.

### Confirming Destructive Actions

For actions that cannot be easily undone (deleting a record, closing an account,
canceling a subscription), confirm before sending the request ([WCAG 3.3.4 Error
Prevention][wcag-error-prevention]). Turbo ships a
[`data-turbo-confirm`][turbo-confirm] attribute that opens the browser's native
`confirm()` dialog and submits only if the user agrees:

[turbo-confirm]: https://turbo.hotwired.dev/reference/attributes
[wcag-error-prevention]: https://www.w3.org/WAI/WCAG22/Understanding/error-prevention-legal-financial-data.html

```html+erb
<%= button_to "Delete account", account_path, method: :delete,
      data: { turbo_confirm: "This cannot be undone. Delete account?" } %>
```

The native dialog is accessible by default: the browser manages focus, traps it
inside the dialog, announces the title and buttons through the screen reader,
and accepts Enter and Escape to accept or cancel. Relying on it instead of a
custom `<dialog>` avoids having to reimplement that behavior correctly. When the
design really needs a custom confirmation dialog, see [Dialogs](#dialogs) for
the native `<dialog>` alternative.

Testing
-------

Accessibility testing works best as a combination of two complementary
approaches. **Automated checks** catch a defined set of known issue patterns
quickly and repeatedly, so they are cheap to run and can gate deploys in CI.
**Manual tests with actual assistive technologies** reveal everything else:
label quality, navigation flow, announcement timing, semantic structure, and
every judgment call a linter cannot make. Both are necessary, and neither alone
is enough.

### Automated Testing

Automated tools catch only a fraction of accessibility issues (the commonly
cited range is roughly 30 to 50 percent): things like missing labels, low
contrast, and invalid ARIA. They cannot evaluate the quality of labels, the
logic of navigation flow, or the usability of screen reader announcements.
Automated tests are a floor, not a ceiling.

Recommended tools:

* [axe-core][axe-core]: the industry standard accessibility testing engine,
  available as a [browser extension][axe-devtools] and as integrations for test
  frameworks.
* [Herb][herb]: an HTML-aware linter for `.html.erb` files. Integrating it with
  an editor or a CI pipeline surfaces accessibility issues while templates are
  still being written, before the code reaches the browser. Its rule set keeps
  growing, so the same integration picks up new checks over time.
* [Lighthouse][lighthouse]: built into Chrome DevTools, includes accessibility
  audits.
* [Firefox Accessibility Inspector][firefox-a11y-inspector]: built into Firefox
  DevTools, shows the accessibility tree.
* [WAVE][wave] and [Accessibility Insights][accessibility-insights]: alternative
  browser extensions that overlay findings directly on the page and can
  complement axe-core by surfacing different issues or presenting the same ones
  in a different way.

[axe-core]: https://github.com/dequelabs/axe-core
[axe-devtools]: https://www.deque.com/axe/devtools/extension/
[herb]: https://herb-tools.dev/
[lighthouse]: https://developer.chrome.com/docs/lighthouse/accessibility/
[firefox-a11y-inspector]: https://firefox-source-docs.mozilla.org/devtools-user/accessibility_inspector/
[wave]: https://wave.webaim.org/extension/
[accessibility-insights]: https://accessibilityinsights.io/

#### Integrating axe-core in System Tests

New Rails applications no longer include system tests by default. Generate the
scaffolding first, which creates `test/application_system_test_case.rb` and a
`test/system/` directory:

```bash
$ bin/rails generate system_test accessibility_audits
```

See [Generating System Tests](testing.html#generating-system-tests) for details.
Then add the [`axe-core-capybara`][axe-core-capybara] integration and define an
`assert_accessible` helper on
[`ApplicationSystemTestCase`][ApplicationSystemTestCase] that forwards keyword
arguments to `Axe::Matchers::BeAxeClean`:

[axe-core-capybara]: https://github.com/dequelabs/axe-core-gems/tree/develop/packages/axe-core-capybara
[ApplicationSystemTestCase]: https://api.rubyonrails.org/classes/ActionDispatch/SystemTestCase.html

```ruby
# Gemfile
group :test do
  # ...
  gem "axe-core-capybara"
end
```

```ruby
# test/application_system_test_case.rb
require "test_helper"
require "axe-capybara"
require "axe/matchers/be_axe_clean"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  def assert_accessible(**options)
    options
      .inject(Axe::Matchers::BeAxeClean.new) do |matcher, (method, value)|
        matcher.public_send(method, *Array.wrap(value))
      end
      .audit(page).then do |audit|
        assert audit.passed?, audit.failure_message
      end
  end
end
```

```ruby
# test/system/accessibility_audits_test.rb
require "application_system_test_case"

class AccessibilityAuditsTest < ApplicationSystemTestCase
  test "home page is accessible" do
    visit root_path
    assert_accessible
  end
end
```

Calling `assert_accessible` without options runs the rule set axe enables by
default: WCAG 2.0, 2.1, and 2.2 Level A and AA, plus best-practice rules.
AAA-level rules and experimental rules are excluded by default and must be opted
into explicitly.

Each keyword argument maps to a chainable method on the matcher:

| Option | Accepts | Purpose |
|---|---|---|
| `within:` | CSS selector, node, or array | Limit the audit to elements inside these selectors |
| `excluding:` | CSS selector, node, or array | Exclude these elements from the audit |
| `according_to:` | Tag or array of tags | Filter rules by axe tag (replaces the default rule set) |
| `checking:` | Rule ID or array | Add specific rules on top of the default set |
| `checking_only:` | Rule ID or array | Run only these specific rules |
| `skipping:` | Rule ID or array | Disable specific rules |
| `with_options:` | Hash | Raw options passed directly to `axe.run` |

The full list of rule IDs is available in the [axe rules
documentation][axe-rules], and the list of supported tags is in the [axe-core
API documentation][axe-api]. Common tags include `wcag2a`, `wcag2aa`,
`wcag22aa`, `best-practice`, `section508`, and `EN-301-549`.

[axe-rules]: https://dequeuniversity.com/rules/axe/
[axe-api]: https://www.deque.com/axe/core-documentation/api-documentation/

Use these options to push the conformance level higher than the default. For
example, enabling AAA contrast on top of the default rules:

```ruby
test "home page enforces AAA color contrast" do
  visit root_path
  assert_accessible checking: "color-contrast-enhanced"
end
```

Or running an audit against a specific set of standards. Note that
`according_to:` replaces the default rule set, so every tag that should apply
must be listed explicitly. The example below covers WCAG 2.2 AA plus
best-practice, Section 508 (United States), and EN 301 549 (European Union):

```ruby
test "home page conforms to WCAG 2.2 AA plus Section 508 and EN 301 549" do
  visit root_path
  assert_accessible according_to: [
    "wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa",
    "best-practice", "section508", "EN-301-549"
  ]
end
```

#### Writing Accessible System Tests

Write system tests that interact with the application the way assistive
technology users do. [Rails system tests](testing.html#system-testing) use
[Capybara][capybara] under the hood, and its finders already work in terms of
the accessible name. Prefer finding elements by their **accessible names**
(labels, text content) instead of by implementation details like IDs, `name`
attributes, placeholders, or CSS classes:

[capybara]: https://teamcapybara.github.io/capybara/

```ruby
# Avoid: relies on implementation details
fill_in "user_email_address", with: "user@example.com"   # HTML id
fill_in "user[email_address]", with: "user@example.com"  # name attribute
fill_in "you@example.com", with: "user@example.com"      # placeholder

# Prefer: uses the label text, same as a screen reader would
fill_in "Email address", with: "user@example.com"
```

Use semantic finders for actions, and their `assert_*` counterparts for
verification. Both locate elements by accessible name:

```ruby
click_button "Save"            # finds by accessible name
click_link "View profile"      # finds by link text
check "Remember me"            # finds by label text
choose "Monthly billing"       # finds by label text
select "Canada", from: "Country"

assert_button "Save"           # asserts a button with that name exists
assert_link "View profile"     # asserts a link with that text exists
assert_field "Email address", with: "user@example.com"
```

Scope assertions within landmarks so the test verifies page structure and not
just the presence of text anywhere on the page. When a page has multiple
landmarks of the same type, resolve them by role and accessible name:

```ruby
within "main" do
  assert_text "Welcome"
end

# When several <nav> elements exist, disambiguate by their accessible name:
within :element, "nav", "aria-label" => "Primary" do
  assert_link "Home", href: root_path
end

within :element, "nav", "aria-label" => "Footer" do
  assert_link "Privacy", href: privacy_path
end
```

A table's caption is its accessible name, so scope assertions on tabular data by
caption. Rows are then checked as a group rather than as free text somewhere on
the page:

```ruby
assert_table "Users", with_rows: [
  { "Email address" => "user@example.com", "Name" => "User" },
  { "Email address" => "other@example.com", "Name" => "Other" }
]
```

Capybara's finders also accept filters for the same states assistive
technologies report: `focused`, `disabled`, `checked`, and ARIA attributes.
Prefer these filters over CSS pseudo-class selectors so the test reads like the
behavior it checks:

```ruby
# Avoid: CSS selector with a pseudo-class, brittle and harder to read
assert_css "input#user_email_address:focus"

# Prefer: semantic finder with a state filter
assert_field "Email address", focused: true
assert_field "Remember me", checked: true
```

For most flows, the semantic finders above are enough. Some interactions, such
as verifying tab order through a dialog or that a skip link lands on the main
content, depend on keyboard input specifically. Capybara drives those through
`send_keys` on the page or on an element:

```ruby
# Move focus to the next focusable element
page.send_keys :tab

# Activate the focused element
page.send_keys :enter
```

Use keyboard driving for the flows that depend on it, and the semantic finders
everywhere else.

### Manual Testing

Manual testing exercises the application the way real users of assistive
technologies do. No automated tool can judge whether a label makes sense,
whether the navigation order is logical, or whether a dynamic update reaches the
user in time. A person using the application does.

Where possible, extend that work with feedback from people who rely on assistive
technologies every day. A colleague who uses a screen reader, a customer who
reports an issue, or a scheduled session with a disability consultant will catch
things the team cannot judge from the outside: how an interaction actually
feels, which patterns look correct in code but break under real use, which
announcements land in time and which get lost. Tools and team-run checks
establish a floor, but only feedback from daily users of assistive technology
tells whether the application actually works in practice.

#### Keyboard

Keyboard testing is the foundation every other manual test builds on. Screen
readers, voice control, and switch devices all rely on the same focusable set
and focus order, so if a control cannot be reached or activated with a keyboard,
none of those tools can operate it either.

Navigate the entire application using only the keyboard. The keys that matter
most:

* **Tab** / **Shift+Tab**: move between interactive elements.
* **Enter**: activate links and buttons.
* **Space**: activate buttons, toggle checkboxes.
* **Arrow keys**: navigate within select menus and radio groups.
* **Escape**: close dialogs and popovers.

Verify that:

* Every interactive element is reachable with Tab ([WCAG 2.1.1
  Keyboard][wcag-keyboard]).
* Focus order follows the visual reading order ([WCAG 2.4.3 Focus
  Order][wcag-focus-order]).
* The currently focused element has a visible focus indicator ([WCAG 2.4.7 Focus
  Visible][wcag-focus-visible]).
* The focused element is not hidden by sticky or fixed content ([WCAG 2.4.11
  Focus Not Obscured (Minimum)][wcag-focus-not-obscured-min]).
* No element traps keyboard focus. Modal dialogs contain focus, but Escape
  always releases it ([WCAG 2.1.2 No Keyboard Trap][wcag-no-keyboard-trap]).
* Drag-and-drop and other pointer-only gestures have a keyboard alternative
  ([WCAG 2.5.1 Pointer Gestures][wcag-pointer-gestures], [WCAG 2.5.7 Dragging
  Movements][wcag-dragging-movements]).

[wcag-no-keyboard-trap]: https://www.w3.org/WAI/WCAG22/Understanding/no-keyboard-trap.html
[wcag-pointer-gestures]: https://www.w3.org/WAI/WCAG22/Understanding/pointer-gestures.html
[wcag-dragging-movements]: https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html

On macOS, Tab moves focus between text boxes and lists only by default. To match
the behavior of the other platforms and reach every focusable element, enable
**Keyboard navigation** at System Settings > Keyboard, which also has a toggle
shortcut, `Ctrl + F7`.

Browser tooling makes tab order easier to inspect than tabbing through the page
by hand. **Firefox** exposes a [Show Tabbing Order][firefox-tab-order] toggle in
the Accessibility panel of its Developer Tools that overlays numbered badges on
every focusable element in the order Tab will visit them. The [**Accessibility
Insights** browser extension][accessibility-insights] provides a Tab Stop
checker that draws an arrow path between consecutive tab stops and flags
out-of-order jumps directly on the page. Either one turns a focus-order
regression into a visual diff rather than something a tester has to reconstruct
from memory.

[firefox-tab-order]: https://firefox-source-docs.mozilla.org/devtools-user/accessibility_inspector/#show-web-page-tabbing-order

Switch users rely on this same focusable set, but their scan advances one
element at a time, so a long list of inline actions can take dozens of seconds
to traverse. Where the design allows, grouping secondary actions behind a menu
or a [disclosure widget](#disclosure-with-details-and-summary) keeps the scan
short for everyone.

#### Screen Readers

Screen readers read the page aloud and let users navigate it without looking at
the screen. As covered in [How Screen Readers Work](#how-screen-readers-work),
they interpret the HTML (not the pixels), so every label, heading, and landmark
announced comes straight from the markup. Testing with one reveals the widest
range of accessibility issues of any manual test: poorly worded labels,
confusing navigation order, dynamic changes that are never announced, and
semantic structure that does not match the visual layout.

On desktop they are driven by the keyboard, on mobile by touch gestures. Testing
one of each is enough as a baseline. Pick whichever matches the operating
systems at hand:

| OS | Screen Reader | Browser |
|----|---------------|---------|
| Windows | [NVDA](https://www.nvaccess.org/download/) | Edge, Chrome, or Firefox |
| macOS | VoiceOver (built-in) | Safari |
| Linux | [Orca](https://orca.gnome.org/) | Firefox |
| iOS / iPadOS | VoiceOver (built-in) | Safari |
| Android | TalkBack (built-in) | Chrome |

Every reader in this list except Orca ships a **Screen Curtain** feature (called
**Hide screen** on Android) that blacks out the display while the reader keeps
announcing everything. It is the closest a sighted tester can get to the blind
user experience, since every check then relies on what is heard rather than what
is on the screen.

##### Running a Test Session

Using a screen reader for the first time is a new experience. Keys do things
they normally do not, and a familiar page suddenly reveals how much of its
content is invisible to the reader. The goal of a first session is to experience
that shift, not to master every shortcut.

Pick a page that exercises the parts of the application worth checking (forms,
navigation, dynamic updates) and walk through these steps:

1. **Load the page.** The title announced should match where the user is ([WCAG
   2.4.2 Page Titled][wcag-page-titled]).
2. **Step through the landmarks.** The main content area should be reachable in
   one jump. If several `<nav>` or `<aside>` elements exist, each should have a
   distinct name ([WCAG 1.3.1 Info and Relationships][wcag-info-relationships]).
3. **Step through the headings.** The result should read like a table of
   contents: a single `<h1>` describing the page, a logical outline below it, no
   skipped levels, and every major section represented ([WCAG 1.3.1 Info and
   Relationships][wcag-info-relationships]).
4. **Step through the interactive elements.** Every link, button, and form field
   should be reached, announced with a clear name, and activated by the expected
   action ([WCAG 4.1.2 Name, Role, Value][wcag-name-role-value]).
5. **Check images and tables.** Images should announce useful alt text or stay
   silent if purely decorative ([WCAG 1.1.1 Non-text
   Content][wcag-non-text-content]). For each table, entering it should announce
   the caption and the table's dimensions, and moving between cells in all four
   directions should work, with each move announcing the cell's value together
   with its column and row headers so the value is never read without its
   context ([WCAG 1.3.1 Info and Relationships][wcag-info-relationships]).
6. **Fill and submit a form.** Once with valid data, once with an error. Labels,
   help text, and validation errors should all be announced without requiring
   the tester to look at the screen ([WCAG 3.3.2 Labels or
   Instructions][wcag-labels-instructions], [WCAG 3.3.1 Error
   Identification][wcag-error-identification]).
7. **Trigger any dynamic behavior.** Flash messages, Turbo updates, dialogs, and
   live filters. Each change should either move focus into the updated content
   or, when moving focus would be disruptive, be announced via a live region
   ([WCAG 4.1.3 Status Messages][wcag-status-messages]) so the user can perceive
   that something happened.

If any step produces no announcement, a confusing announcement, or a name that
does not match what the element does, the page has an accessibility issue worth
fixing before shipping.

##### NVDA (Windows)

[NVDA](https://www.nvaccess.org/download/) is a free, open-source Windows screen
reader. It follows the browse-mode / focus-mode model described in [How Screen
Readers Work on Desktop](#on-desktop): single-letter keys (`H`, `K`, `B`, `F`,
...) navigate in browse mode, and the reader switches to focus mode
automatically when the user lands on a form field. Instead of announcing the
switch in speech, NVDA plays a short tone, one per mode.

NVDA's commands are prefixed with the **NVDA key**: `Insert`, `Extended Insert`
(numpad 0), or `Caps Lock`, selected at install. Hold it while pressing the rest
of the combination.

The [NVDA User Guide][nvda-guide] documents every command and setting. NVDA does
not include a built-in interactive tutorial.

[nvda-guide]: https://download.nvaccess.org/documentation/userGuide.html

Setup:

1. Download and install [NVDA](https://www.nvaccess.org/download/).
2. On first launch, the "Welcome to NVDA" dialog asks for the keyboard layout
   and which physical key acts as the NVDA key (`Insert`, `Extended Insert`, or
   `Caps Lock`). On a laptop, the `Laptop` layout avoids shortcuts that need the
   numpad.
3. Start NVDA with `Ctrl + Alt + N`. A startup sound confirms it is running.
4. Open Edge, Chrome, or Firefox.

Essential commands:

| Action | Keys |
|--------|------|
| Toggle Input Help (announces each key and what it does without running it) | `NVDA + 1` |
| Open the NVDA menu | `NVDA + N` |
| Quit NVDA | `NVDA + Q` |
| Stop speaking | `Ctrl` |
| Toggle Screen Curtain | `NVDA + Ctrl + Escape` |
| Toggle browse/focus mode | `NVDA + Space` |
| Next / previous line | `Down Arrow` / `Up Arrow` |
| Next / previous landmark | `D` / `Shift+D` |
| Next / previous heading | `H` / `Shift+H` |
| Next / previous heading at level 1-6 | `1`-`6` / `Shift+1`-`Shift+6` |
| Next / previous link | `K` / `Shift+K` |
| Next / previous button | `B` / `Shift+B` |
| Next / previous form field | `F` / `Shift+F` |
| Next / previous list | `L` / `Shift+L` |
| Next / previous graphic | `G` / `Shift+G` |
| Next / previous table | `T` / `Shift+T` |
| Navigate between cells in a table | `Ctrl + Alt + Arrow` keys |

The single-letter keys only work in browse mode. If pressing `H` does nothing
(or does something unexpected), NVDA has switched to focus mode, and `NVDA +
Space` toggles back.

##### VoiceOver (macOS)

VoiceOver works differently from NVDA. Its primary navigation is `VO + Right
Arrow` / `VO + Left Arrow`, which moves the **VoiceOver cursor** (its own focus
rectangle) from one item to the next and announces each one.

The interface is hierarchical. The browser window, its toolbars, the web content
area, forms, and tables all count as single "groups" at the outer level. `VO +
Right Arrow` moves past a group as a single item without dropping into it. To
navigate **inside** a group, the user first **interacts with it**: `VO + Shift +
Down Arrow` drills in and `VO + Shift + Up Arrow` steps back out to the parent.
Once interacting, `VO + Right / Left Arrow` continues to move, but now through
the group's contents. The mental model is opening and closing folders. On the
web, the user typically interacts with the content area once after a page loads
so that `VO + Right / Left` starts moving through headings and paragraphs
instead of around them.

Navigation by element type also happens through the **Rotor**, a category
picker. `VO + Command + Right / Left Arrow` cycles through categories (Headings,
Links, Form Controls, Landmarks, ...) and `VO + Command + Down / Up Arrow` moves
between items in the current category.

VoiceOver also offers **Single-Key Quick Nav**, which turns on single-letter
navigation similar to NVDA and Orca: `H` jumps to the next heading, `B` to the
next button, `K` to the next link, and so on.

VoiceOver's commands are prefixed with a **VO modifier**: hold either `Control +
Option` or `Caps Lock` while pressing the rest of the combination.

The [VoiceOver User Guide][vo-mac-guide] documents every command and setting.
Apple also ships an interactive **VoiceOver Tutorial**, which can be launched
with `VO + Command + F8` or from System Settings > Accessibility > VoiceOver >
Open VoiceOver Tutorial.

Setup:

1. Enable VoiceOver by pressing `Command + F5`, asking Siri to "Turn on
   VoiceOver", or toggling it in System Settings > Accessibility > VoiceOver.
2. Open Safari and navigate to a page.

Essential commands:

| Action | Keys |
|--------|------|
| Toggle Keyboard Help (announces each key and what it does without running it) | `VO + K` |
| Open VoiceOver Utility | `VO + F8` |
| Turn VoiceOver off | `Command + F5` |
| Stop speaking | `Ctrl` |
| Toggle Screen Curtain | `VO + Shift + F11` |
| Toggle Single-Key Quick Nav | `VO + Q` |
| Next / previous item | `VO + Right Arrow` / `VO + Left Arrow` |
| Activate the focused item | `VO + Space` |
| Start / stop interacting with a group | `VO + Shift + Down Arrow` / `VO + Shift + Up Arrow` |
| Next / previous Rotor category | `VO + Command + Right / Left Arrow` |
| Next / previous item in the selected Rotor category | `VO + Command + Down / Up Arrow` |
| Next / previous heading | `VO + Command + H` / `VO + Command + Shift + H` |
| Next / previous link | `VO + Command + L` / `VO + Command + Shift + L` |
| Next / previous form control | `VO + Command + J` / `VO + Command + Shift + J` |
| Next / previous list | `VO + Command + X` / `VO + Command + Shift + X` |
| Next / previous graphic | `VO + Command + G` / `VO + Command + Shift + G` |
| Next / previous table | `VO + Command + T` / `VO + Command + Shift + T` |
| Navigate between cells in a table | `VO + Arrow` keys (after interacting with the table) |

NOTE: F-key shortcuts like `Command + F5` and `VO + Shift + F11` assume the
F-keys are set to act as standard function keys on the Mac. Where the F-keys
double as media controls (the default on most Macs), add `Fn` to the
combination.

##### Orca (Linux)

Orca follows the same browse / focus model as NVDA, with different key bindings.
Single-letter keys navigate while reading, and Orca switches to focus mode
automatically when the user enters a form field.

Orca works on any Linux desktop that supports the Assistive Technology Service
Provider Interface (AT-SPI), which covers most of them. Install it through the
distribution's package manager if it is not already present: `sudo apt install
orca` on Debian-based systems, `sudo dnf install orca` on Fedora, or the
equivalent elsewhere.

Orca's commands are prefixed with an **Orca modifier**: `Insert` on the Desktop
keyboard layout, `CapsLock` on the Laptop layout. Hold it while pressing the
rest of the combination.

The [Orca User Guide][orca-guide] documents every command and setting. Orca does
not include a built-in interactive tutorial.

[orca-guide]: https://help.gnome.org/users/orca/stable/

Setup:

1. Start Orca with `Super + Alt + S` or run `orca` from a terminal.
2. Open Firefox and navigate to a page.

Essential commands:

| Action | Keys |
|--------|------|
| Toggle Learn Mode (announces each key and what it does without running it) | `Orca Modifier + H` |
| Open Orca Preferences | `Orca Modifier + Space` |
| Quit Orca | `Orca Modifier + Q` |
| Stop speaking | `Ctrl` |
| Toggle browse/focus mode | `Orca Modifier + A` |
| Next / previous line | `Down Arrow` / `Up Arrow` |
| Next / previous landmark | `M` / `Shift+M` |
| Next / previous heading | `H` / `Shift+H` |
| Next / previous heading at level 1-6 | `1`-`6` / `Shift+1`-`Shift+6` |
| Next / previous link | `K` / `Shift+K` |
| Next / previous button | `B` / `Shift+B` |
| Next / previous form field | `F` / `Shift+F` |
| Next / previous list | `L` / `Shift+L` |
| Next / previous table | `T` / `Shift+T` |
| Navigate between cells in a table | `Alt + Shift + Arrow` keys |

Orca has no Screen Curtain equivalent, so reducing the monitor's brightness to
zero is the simplest substitute.

##### Mobile Screen Readers

VoiceOver on iOS/iPadOS and TalkBack on Android share a common touch model that
differs from a standard touch device. A single tap does **not** activate what is
under the finger, but instead moves the reader's focus to that element and
announces it. To **activate** the focused element, double-tap **anywhere on the
screen**: the double-tap always targets whatever has reader focus, not what is
under the finger. Swiping right or left moves focus to the next or previous
element in DOM order.

Navigation by element type is also available, through a different interface on
each platform:

* **VoiceOver** uses the **Rotor** (a two-finger twist on the screen, like
  turning a dial) to pick a category: Headings, Links, Form Controls, Landmarks,
  and so on. Once a category is selected, swiping up or down moves among
  elements of that type.
* **TalkBack** uses **reading controls**: swipe up-then-down (or down-then-up)
  without lifting the finger to cycle between categories, then swipe up or down
  to move within the selected one. The **TalkBack menu** (swipe down-then-right)
  also lists every category.

The [VoiceOver User Guide for iPhone][vo-ios-guide] and the [TalkBack user
guide][talkback-guide] document every gesture.

An **interactive tutorial** walks through the gestures on each platform. On
iOS/iPadOS, it lives at Settings > Accessibility > VoiceOver > VoiceOver
Tutorial. On Android, TalkBack launches it automatically the first time it is
enabled, and it stays available under TalkBack settings > Tutorial and help >
Tutorial.

A **practice mode** is also available, the mobile equivalent of the desktop help
modes: performing a gesture while practice is on announces what it does, without
running it. On iOS/iPadOS, VoiceOver Practice is toggled by a **four-finger
double-tap** or from Settings > Accessibility > VoiceOver > VoiceOver Practice.
On Android, the equivalent lives under TalkBack settings > Tutorial and help >
Practice gestures.

Setup:

1. Enable the reader. On iOS/iPadOS: Settings > Accessibility > VoiceOver, or
   ask Siri to "turn on VoiceOver". On Android: Settings > Accessibility >
   TalkBack, or hold both volume keys down for a few seconds after opting into
   the shortcut. The same methods turn the reader off again.
2. Open Safari on iOS/iPadOS, or Chrome on Android.

Essential gestures:

| Action | VoiceOver (iOS/iPadOS) | TalkBack (Android) |
|--------|------------------------|--------------------|
| Focus the element under the finger | Tap | Tap |
| Activate the focused element | Double-tap anywhere | Double-tap anywhere |
| Next / previous element | Swipe right / left | Swipe right / left |
| Pick a navigation category | Two-finger twist (Rotor) | Swipe up-then-down |
| Move in the selected category | Swipe up / down | Swipe up / down |
| Scroll | Three-finger swipe | Two-finger swipe |
| Pause or resume speech | Two-finger tap | Two-finger tap |
| Toggle Screen Curtain | Three-finger triple-tap | TalkBack menu > Hide screen |

#### Zoom and Magnification

Browser zoom and screen magnifiers test different things. Browser zoom scales
the whole viewport, so the concern is layout reflow. Screen magnifiers enlarge a
small region of the screen, so the concern is whether important content stays
inside the user's view.

##### Browser Zoom

Browser zoom has two tests:

* Set browser zoom to 200% and check that text is readable, does not get
  clipped, and does not collide with or hide other elements ([WCAG 1.4.4 Resize
  Text][wcag-resize]).
* Open DevTools at 1280px wide, set zoom to 400%, and confirm nothing requires
  scrolling in two directions and no interactive element is cut off or
  unreachable ([WCAG 1.4.10 Reflow][wcag-reflow]).

##### Screen Magnifiers

Screen magnifier users see only a small portion of the page at high zoom (often
3x to 10x) and pan around it. This reveals issues that browser zoom does not:
error messages that appear far from the field they describe, tooltips that open
off the magnified area, sticky headers that cover the focused element, and faint
focus indicators that get lost at high magnification.

Every major operating system ships a magnifier:

| OS | Tool | How to enable |
|----|------|---------------|
| Windows | [Magnifier][magnifier-win] | `Windows + Plus`, or Settings > Accessibility > Magnifier |
| macOS | [Zoom][magnifier-mac] | System Settings > Accessibility > Zoom |
| Linux | Built-in magnifier | Under the desktop environment's accessibility settings |
| iOS / iPadOS | [Zoom][magnifier-ios] | Settings > Accessibility > Zoom |
| Android | [Magnification][magnifier-android] | Settings > Accessibility > Magnification |

[magnifier-win]: https://support.microsoft.com/en-us/windows/use-magnifier-to-make-things-on-the-screen-easier-to-see-414948ba-8b1c-d3bd-8615-0e5e32204198
[magnifier-mac]: https://support.apple.com/guide/mac-help/zoom-in-on-your-mac-screen-mchl779716b8/mac
[magnifier-ios]: https://support.apple.com/guide/iphone/zoom-in-iph3e2e367e/ios
[magnifier-android]: https://support.google.com/accessibility/android/answer/6006949

Turn the magnifier on at 4x or 5x, then navigate a representative flow (sign up,
fill a form, submit, and recover from errors). Watch for:

* The focus indicator staying visible as focus moves.
* Field labels, inline errors, and tooltips appearing close enough to the
  associated control that both fit inside the magnified region.
* No critical content hidden behind sticky or fixed UI.
* Dynamic changes (flash messages, live updates) that happen outside the
  magnified region, since the user will miss them without a live region
  announcing them.

#### Color and Contrast

Contrast issues are the easiest accessibility failures to cause with CSS and one
of the easiest to measure. The work falls into four checks: contrast of the UI
itself, whether color alone carries meaning, how the UI behaves under a forced
palette, and how it behaves when the user inverts colors at the OS level.

Verify contrast ratios directly with:

* **axe DevTools**: runs a full audit that includes contrast checks.
* **Chrome DevTools**: inspect an element and click the color value in the
  Styles panel to see the ratio.
* **Firefox Accessibility Inspector**: the Accessibility panel highlights
  contrast issues directly.

All three cover text contrast ([WCAG 1.4.3 Contrast (Minimum)][wcag-contrast])
and UI component contrast ([WCAG 1.4.11 Non-text
Contrast][wcag-non-text-contrast]). See [Color](#color) for the specific
thresholds.

Check that no information depends on color alone: a red border on an invalid
field, a green dot for "online", or a red bar in a chart each need a non-color
cue (a text label, an icon, or a pattern) that users who cannot distinguish the
colors can still perceive ([WCAG 1.4.1 Use of Color][wcag-use-of-color]). Chrome
DevTools and Edge DevTools surface this without leaving the browser: in the
**Rendering** panel, **Emulate vision deficiencies** approximates how the page
looks with protanopia, deuteranopia, tritanopia, achromatopsia, blurred vision,
or reduced contrast. The same panel exposes **Emulate CSS media feature
forced-colors** and **Emulate CSS media feature prefers-contrast** for the
matching media queries described in [Respecting User
Preferences](#respecting-user-preferences). These previews catch the most
obvious regressions early but do not replace testing on the operating system
itself.

Then turn on a **high-contrast mode** and confirm the UI remains usable.
**Contrast themes** on Windows (Settings > Accessibility > Contrast themes) or
**Increase contrast** on macOS (System Settings > Accessibility > Display) force
the system palette, and any UI element that relied on a specific color may
disappear or become unreadable.

Some users go further and invert the system colors entirely. Inverted colors do
not expose a CSS media query, so the stylesheet cannot react to them and the
operating system handles the substitution on its own. The most common surprise
is `box-shadow`, where a light shadow on a light surface inverts into a dark
shadow on a dark surface that no longer behaves as a shadow visually. Toggling
the OS invert on once per release and walking through a representative flow
catches these regressions early.

| OS | Tool | How to enable |
|----|------|---------------|
| Windows | [Color filters][invert-win] (Inverted) | Settings > Accessibility > Color filters |
| macOS | [Invert colors][invert-mac] | System Settings > Accessibility > Display |
| iOS / iPadOS | [Smart Invert / Classic Invert][invert-ios] | Settings > Accessibility > Display & Text Size |
| Android | [Color inversion][invert-android] | Settings > Accessibility > Color and motion |

[invert-win]: https://support.microsoft.com/en-us/windows/use-color-filters-in-windows-43893e44-b8b3-2e27-1a29-b0c15ef0e5ce
[invert-mac]: https://support.apple.com/guide/mac-help/change-display-settings-for-accessibility-mchl1bf64bcd/mac
[invert-ios]: https://support.apple.com/guide/iphone/display-and-text-size-iph3e2e1fb0/ios
[invert-android]: https://support.google.com/accessibility/android/answer/11183305

No major Linux desktop ships a built-in color inversion feature, so testing has
to happen on one of the other platforms.

#### Voice Control

Voice control users speak the visible text or accessible name of a control to
activate it. An icon-only button with a descriptive `aria-label` is reachable by
saying that label. Two patterns break this interaction:

* **No accessible name at all.** Controls without visible text, `aria-label`, or
  any other source of a name give voice control nothing to match ([WCAG 4.1.2
  Name, Role, Value][wcag-name-role-value]).
* **Accessible name that does not include the visible text.** A button labeled
  "Submit" whose `aria-label` overrides its name to "Save form" cannot be
  activated by saying "Click Submit" ([WCAG 2.5.3 Label in
  Name][wcag-label-in-name]).

| OS | Tool | How to enable |
|----|------|---------------|
| Windows | [Voice access][voice-access-win] | Settings > Accessibility > Speech |
| macOS | [Voice Control][voice-control-mac] | System Settings > Accessibility > Voice Control |
| iOS / iPadOS | [Voice Control][voice-control-ios] | Settings > Accessibility > Voice Control |
| Android | [Voice Access][voice-access-android] | Settings > Accessibility > Voice Access |

[voice-access-win]: https://support.microsoft.com/en-us/topic/set-up-voice-access-9fc44e29-12bf-4d86-bc4e-e9bb69df9a0e
[voice-control-mac]: https://support.apple.com/guide/mac-help/turn-voice-control-on-or-off-mchl63d14732/mac
[voice-control-ios]: https://support.apple.com/guide/iphone/voice-control-iph2c21a3c88/ios
[voice-access-android]: https://support.google.com/accessibility/android/answer/6151848

No built-in voice control ships with any major Linux desktop.

To run a session, enable voice control, open a representative page, and try to
reach every major control by speaking its name. The activation verb differs by
platform: **"Click [name]"** on Windows and macOS, **"Tap [name]"** on iOS,
iPadOS, and Android. Replace `[name]` with the element's visible text or
accessible name. If an element has no accessible name, the tool cannot identify
it, so voice control users cannot reach it.
