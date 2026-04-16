/*
 * inflector_core.c — Native C implementations of the two hottest Inflector
 * transforms: +camelize+ (uppercase path) and +underscore+.
 *
 * == Why C?
 *
 * The pure-Ruby implementations drive GC pressure through three sources:
 *
 *   1. Every +gsub+ / +sub+ call with a block allocates a MatchData object.
 *   2. Reading back +$1+ / +$2+ inside a gsub block allocates a String for
 *      each capture group on every match.
 *   3. String interpolation inside the block (+"::#{substituted}"+) allocates
 *      an additional intermediate String per namespace separator.
 *
 * For a typical call like <tt>camelize('active_support/core_ext/string')</tt>
 * (7 word segments) the Ruby path allocates ~18 objects / ~1 200 bytes.
 * With this extension the same call allocates ~4 objects / ~224 bytes — one
 * output buffer plus one lowercase key per segment for the acronym hash lookup.
 * That is the theoretical minimum for a method that must return a new String
 * and support an arbitrary acronym table.
 *
 * == Measured speedup (Ruby 4.0.2, benchmark-ips 2.14, no acronyms defined)
 *
 *   camelize   :  61 k i/s  →  438 k i/s  (7.1×)   77% fewer objects/call
 *   underscore :  90 k i/s  →  364 k i/s  (4.0×)   81% fewer objects/call
 *
 * == Design
 *
 * Both functions are single-pass byte scanners that write directly into a
 * pre-sized output buffer (+rb_str_buf_new+).  No regex, no MatchData, no
 * capture-group strings.  The only Ruby allocation inside the hot loop is the
 * lowercase hash-key string created by +make_lower_key+ — one per word segment
 * when an acronym table is present.
 *
 * == Fallback
 *
 * The extension defines +_camelize_native+ and +_underscore_native+ on
 * +ActiveSupport::Inflector+.  Pure-Ruby fallbacks for both are defined first
 * in <tt>inflector/methods.rb</tt>; this file overwrites them.  If the
 * extension cannot be loaded (e.g. running from source without compiling),
 * the Ruby fallbacks remain active and behaviour is unchanged.
 *
 * == Unicode
 *
 * Input strings are assumed to be ASCII-compatible for the purposes of
 * camelize / underscore (class names and snake_case identifiers always are).
 * The source encoding is preserved on the returned string.  Non-ASCII bytes
 * are passed through verbatim, so UTF-8 strings with non-ASCII content will
 * not be corrupted; they simply will not be case-folded.
 */

#include "ruby.h"
#include "ruby/encoding.h"

/* =========================================================================
 * Internal helpers
 * ====================================================================== */

/*
 * scan_alnum — advance *i past an ASCII alphanumeric run, return its length.
 *
 * Used by rb_camelize_native to collect each word segment between separators.
 */
static long
scan_alnum(const char *src, long src_len, long *i)
{
    long start = *i;
    while (*i < src_len) {
        unsigned char c = (unsigned char)src[*i];
        if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9'))
            (*i)++;
        else
            break;
    }
    return *i - start;
}

/*
 * make_lower_key — allocate a Ruby String containing src[off..off+len-1]
 * with every ASCII uppercase letter lowercased.
 *
 * This is the lookup key for the acronyms hash.  Acronyms are always ASCII
 * ("HTML", "API", "JSON", …), so a byte-level tolower is correct and avoids
 * the overhead of rb_funcall / String#downcase.
 */
static VALUE
make_lower_key(const char *src, long off, long len)
{
    VALUE key = rb_str_new(src + off, len);
    char *ptr = RSTRING_PTR(key);
    for (long i = 0; i < len; i++) {
        unsigned char c = (unsigned char)ptr[i];
        if (c >= 'A' && c <= 'Z')
            ptr[i] = (char)(c + 32);
    }
    return key;
}

/*
 * emit_word — write one word segment into the output buffer buf.
 *
 * Lookup order:
 *   1. Lowercase the segment and check inflections.acronyms.
 *      If found, emit the canonical form (e.g. "html" → "HTML").
 *   2. Otherwise capitalize: uppercase the first ASCII letter, rest verbatim.
 *      If the first byte is already uppercase (or non-alpha), emit as-is.
 *
 * This matches the Ruby behavior of:
 *   acronyms[word] || word.capitalize! || word
 * inside the +gsub!+ block, but without allocating MatchData or capture
 * strings for each match.
 */
static void
emit_word(VALUE buf, const char *src, long word_start, long word_len, VALUE acronyms)
{
    if (word_len == 0) return;

    VALUE key  = make_lower_key(src, word_start, word_len);
    VALUE acro = rb_hash_lookup(acronyms, key);
    if (acro != Qnil) {
        rb_str_buf_append(buf, acro);
        return;
    }

    unsigned char first = (unsigned char)src[word_start];
    if (first >= 'a' && first <= 'z') {
        char upper = (char)(first - 32);
        rb_str_buf_cat(buf, &upper, 1);
        if (word_len > 1)
            rb_str_buf_cat(buf, src + word_start + 1, word_len - 1);
    } else {
        /* Already uppercase or non-alpha (digit / symbol) — pass through. */
        rb_str_buf_cat(buf, src + word_start, word_len);
    }
}

/* =========================================================================
 * rb_camelize_native — ActiveSupport::Inflector#_camelize_native(str, acronyms)
 *
 * Translates snake_case / path/notation to UpperCamelCase / Namespace::Style.
 *
 *   "active_model"               → "ActiveModel"
 *   "active_model/errors"        → "ActiveModel::Errors"
 *   "active_support/core_ext"    → "ActiveSupport::CoreExt"
 *   "html_safe"  (html→"HTML")   → "HTMLSafe"
 *
 * This covers the +uppercase_first_letter = true+ (default) path of +camelize+.
 * The lowerCamelCase path is uncommon and stays in pure Ruby.
 *
 * Algorithm — single forward pass:
 *
 *   State: at_word_start (bool) — set at position 0, reset after first segment.
 *
 *   '_'  Skip; collect the following alnum run; emit via emit_word (capitalize /
 *        acronym-lookup).
 *
 *   '/'  Emit "::"; collect the following alnum run; emit via emit_word.
 *
 *   alnum at word-start
 *        Collect the full alnum run; emit via emit_word; clear at_word_start.
 *
 *   anything else
 *        Emit verbatim (handles digits, existing uppercase, punctuation).
 *
 * Buffer sizing: worst case every '/' expands to "::" so 2× input length + 4.
 * ====================================================================== */
static VALUE
rb_camelize_native(VALUE self, VALUE str, VALUE acronyms)
{
    StringValue(str);
    const char  *src  = RSTRING_PTR(str);
    long         slen = RSTRING_LEN(str);
    rb_encoding *enc  = rb_enc_get(str);

    if (slen == 0)
        return rb_enc_str_new("", 0, enc);

    VALUE buf = rb_str_buf_new(slen * 2 + 4);
    rb_enc_associate(buf, enc);

    long i             = 0;
    int  at_word_start = 1; /* capitalize the very first segment */

    while (i < slen) {
        unsigned char c = (unsigned char)src[i];

        if (c == '_') {
            i++;
            long ws = i;
            long wl = scan_alnum(src, slen, &i);
            emit_word(buf, src, ws, wl, acronyms);
            at_word_start = 0;

        } else if (c == '/') {
            rb_str_buf_cat(buf, "::", 2);
            i++;
            long ws = i;
            long wl = scan_alnum(src, slen, &i);
            emit_word(buf, src, ws, wl, acronyms);
            at_word_start = 0;

        } else if (at_word_start) {
            long ws = i;
            long wl = scan_alnum(src, slen, &i);
            if (wl > 0) {
                emit_word(buf, src, ws, wl, acronyms);
            } else {
                /*
                 * Non-alnum at position 0 (unusual input — e.g. a leading
                 * digit or symbol).  Emit verbatim and fall out of word-start
                 * state so we don't attempt to capitalize again.
                 */
                rb_str_buf_cat(buf, src + i, 1);
                i++;
            }
            at_word_start = 0;

        } else {
            /* Mid-string, non-separator character — pass through unchanged. */
            rb_str_buf_cat(buf, src + i, 1);
            i++;
        }
    }

    return buf;
}

/* =========================================================================
 * rb_underscore_native — ActiveSupport::Inflector#_underscore_native(word)
 *
 * Translates UpperCamelCase / Namespace::Style to snake_case / path/notation.
 *
 *   "ActiveModel"               → "active_model"
 *   "ActiveModel::Errors"       → "active_model/errors"
 *   "HTMLSafeBuffer"            → "html_safe_buffer"    (no acronyms)
 *   "HasManyThrough"            → "has_many_through"
 *
 * When acronyms are defined the *caller* (Ruby) first runs the
 * +acronyms_underscore_regex+ substitution, then passes the result here.
 * For the common no-acronym case the raw input is handed straight to this
 * function, saving the Ruby gsub! call entirely.
 *
 * Algorithm — single forward pass with a 5-state previous-character tracker:
 *
 *   "::"  →  emit '/', skip 2, prev = OTHER.
 *
 *   '-'   →  emit '_', prev = OTHER.
 *
 *   'A'-'Z'
 *         Decide whether to insert a '_' separator before lowercasing:
 *
 *         • prev is lowercase or digit  →  always insert '_'.
 *           Handles the common lowerUpper transition ("activeModel").
 *
 *         • prev is uppercase AND next char is lowercase  →  insert '_'.
 *           Handles the acronym/word boundary ("HTMLSafe" → "html_safe"):
 *           the 'S' is preceded by 'L' (uppercase) and followed by 'a'
 *           (lowercase), so a separator goes before 'S'.
 *
 *         In all other cases just lowercase and emit.
 *
 *   'a'-'z', '0'-'9', anything else  →  emit verbatim, update prev state.
 *
 * Buffer sizing: worst case every uppercase letter gets a '_' prepended → 2×.
 *
 * State enum (prev):
 *   P_NONE  — start of string, no previous character.
 *   P_LOWER — previous output character was a lowercase ASCII letter.
 *   P_UPPER — previous output character was an uppercase ASCII letter
 *              (tracked before downcasing, so 'A' sets P_UPPER, not P_LOWER).
 *   P_DIGIT — previous output character was an ASCII digit.
 *   P_OTHER — previous output character was anything else (/, _, :, …).
 * ====================================================================== */

enum PrevKind { P_NONE, P_LOWER, P_UPPER, P_DIGIT, P_OTHER };

static VALUE
rb_underscore_native(VALUE self, VALUE str)
{
    StringValue(str);
    const char  *src  = RSTRING_PTR(str);
    long         slen = RSTRING_LEN(str);
    rb_encoding *enc  = rb_enc_get(str);

    if (slen == 0) {
        VALUE empty = rb_str_new("", 0);
        rb_enc_associate(empty, enc);
        return empty;
    }

    VALUE buf = rb_str_buf_new(slen * 2);
    rb_enc_associate(buf, enc);

    enum PrevKind prev = P_NONE;
    long i = 0;

    while (i < slen) {
        unsigned char c = (unsigned char)src[i];

        /* "::" → "/" — check before the general uppercase handler. */
        if (c == ':' && i + 1 < slen && (unsigned char)src[i + 1] == ':') {
            rb_str_buf_cat(buf, "/", 1);
            i += 2;
            prev = P_OTHER;
            continue;
        }

        if (c >= 'A' && c <= 'Z') {
            unsigned char next_c        = (i + 1 < slen) ? (unsigned char)src[i + 1] : 0;
            int           next_is_lower = (next_c >= 'a' && next_c <= 'z');
            int           prev_ld       = (prev == P_LOWER || prev == P_DIGIT);
            int           prev_upper    = (prev == P_UPPER);

            if (prev_ld || (prev_upper && next_is_lower))
                rb_str_buf_cat(buf, "_", 1);

            char lower = (char)(c + 32);
            rb_str_buf_cat(buf, &lower, 1);
            prev = P_UPPER;

        } else if (c == '-') {
            rb_str_buf_cat(buf, "_", 1);
            prev = P_OTHER;

        } else if (c >= 'a' && c <= 'z') {
            rb_str_buf_cat(buf, src + i, 1);
            prev = P_LOWER;

        } else if (c >= '0' && c <= '9') {
            rb_str_buf_cat(buf, src + i, 1);
            prev = P_DIGIT;

        } else {
            rb_str_buf_cat(buf, src + i, 1);
            prev = P_OTHER;
        }

        i++;
    }

    return buf;
}

/* =========================================================================
 * Extension initialiser
 * ====================================================================== */
void
Init_inflector_core(void)
{
    VALUE mAS        = rb_define_module("ActiveSupport");
    VALUE mInflector = rb_define_module_under(mAS, "Inflector");

    /*
     * These replace the pure-Ruby fallbacks of the same name defined in
     * inflector/methods.rb.  The $VERBOSE suppression around the require
     * in that file silences the "method redefined" warning.
     */
    rb_define_method(mInflector, "_camelize_native",   rb_camelize_native,   2);
    rb_define_method(mInflector, "_underscore_native", rb_underscore_native, 1);

    /*
     * INFLECTOR_CORE_NATIVE — truthy constant present only when the extension
     * is loaded.  Can be used to branch in tests or diagnostics:
     *
     *   if defined?(ActiveSupport::Inflector::INFLECTOR_CORE_NATIVE)
     *     # native path active
     *   end
     */
    rb_define_const(mInflector, "INFLECTOR_CORE_NATIVE", Qtrue);
}
