## Καλώς ήρθες στήν Rails

Η Rails είναι ενα framework για να φτιάχνεις web εφαρμογές σύμφωνα με το [Model-View-Controller (MVC)](http://en.wikipedia.org/wiki/Model-view-controller) πρότυπο.

Καταλαβαίνωντας το MVC πρότυπο είναι το κλειδί για να καταλάβεις την Rails.Το MVC πρότυπο χωρίζει την εφαρμογή σου σε τρεία επίπεδα, το κάθε ενα έχει συγκεκριμένες αρμοδιότητες.

Το Model layer αντιπροσωπεύει το μοντέλο σας (όπως ο λογαριασμός σας, το προϊόν,
Πρόσωπο, Δημοσίευση, κλπ) και ενσωματώνει την επιχειρηματική λογική που είναι ειδικά για την 
εφαρμογή σας. Η Rails, είναι βάση δεδομένων που υποστηρίζεται από τις κατηγορίες μοντέλων που προέρχονται από την ActiveRecord :: Base. Η Active Record σάς επιτρέπει να παρουσιάσετε τα δεδομένα από
σειρές δεδομένων ως αντικείμενα και ενσωματώνουν τα δεδομένα αυτά με επιχειρηματικής λογικής μεθόδους. Μπορείτε να διαβάσετε περισσότερα για Active Record στο [README] του (ActiveRecord / README.rdoc).
Αν και τα περισσότερα μοντέλα στήν Rails υποστηρίζωνται από μια βάση δεδομένων, μοντέλα μπορούν επίσης να είναι απλές κλάσεις Ruby ή κλάσεις που εφαρμόζουν ένα σύνολο διεπαφών, όπως προβλέπεται από
 Active Model module. Μπορείτε να διαβάσετε περισσότερα σχετικά με το  Active Model [README](activemodel / README.rdoc).

Το Controller layer  είναι υπεύθυνο για το χειρισμό των εισερχόμενων αιτήσεων HTTP και
παρέχοντας μια κατάλληλη απάντηση. Συνήθως αυτό σημαίνει επιστροφή HTML, αλλά το controller
μπορεί επίσης να δημιουργήσει XML, JSON, αρχεία PDF, ειδικά για κινητά, και πολλά άλλα. Οι Controllers φορτόνουν και χειρίζονται τα Models.
Στήν Rails, οι εισερχόμενες αιτήσεις δρομολογούνται από την Action Dispatch σε έναν κατάλληλο ελεγκτή, και
οι κατηγορίες  προέρχονται από τον ελεγκτή ActionController :: Base. Action Dispatch and Action Controller ομαδοποιούνται στο Action Pack. Μπορείτε να διαβάσετε περισσότερα για το Action Pack [README](actionpack / README.rdoc).

Το View layer αποτελείται από «πρότυπα» που είναι υπεύθυνα για την παροχή
στα κατάλληλα διαβήματα των πόρων της εφαρμογής σας. τα πρότυπα μπορούν να
έρχονται σε μια ποικιλία μορφών, αλλά τα περισσότερα πρότυπα είναι HTML με ενσωματωμένο
κώδικα Ruby (αρχεία ERB). Τα Views εμφανίζουν την αντίδραση απο τα Controllers.
Επίσης μπορεί να δημιουργήσει το σώμα ενός μηνύματος ηλεκτρονικού ταχυδρομείου. 
Στήν Rails, τα Views εξαρτόνται από το Action View.
Μπορείτε να διαβάσετε περισσότερα για το View [README](actionview / README.rdoc).

## Ξεκινώντας

1. Εγκατάστηστε την  Rails στη γραμμή εντολών αν δεν το έχετε κάνει ακόμη:

        $ gem install rails

2. Στήν γραμμή εντολών, διμιουργίστε μία νέα  Rails εφαρμογή:

        $ rails new myapp

   όπου "myapp" είναι το όνομα τής εφαρμογής.

   Τρέξτε  `--help` ή `-h` για επιλογές.

4. Πηγαίντε στήν διεύθηνση `http://localhost:3000` και θα δείτε:
"Welcome aboard: You're riding Ruby on Rails!"

5. Ακολουθήστε τις οδηγίες για να αρχίσετε να αναπτύσετε την εφαρμογή σας.

    * [Getting Started with Rails](http://guides.rubyonrails.org/getting_started.html)
    * [Ruby on Rails Guides](http://guides.rubyonrails.org)
    * [The API Documentation](http://api.rubyonrails.org)
    * [Ruby on Rails Tutorial](http://www.railstutorial.org/book)

## Συμβολή

Σας ενθαρρύνουμε να συμβάλετε στην Ruby on Rails! Παρακαλώ ελέγξτε το
[Contributing to Ruby on Rails guide](http://edgeguides.rubyonrails.org/contributing_to_ruby_on_rails.html).


## Code Status

[![Build Status](https://travis-ci.org/rails/rails.svg?branch=master)](https://travis-ci.org/rails/rails)

## Άδεια

Η Ruby on Rails  διατίθεται άδεια βάσει της [MIT License](http://www.opensource.org/licenses/MIT).
