Active Record Associations(Kết hợp)
==========================

Bài hướng dẫn này nói về tính năng Associations(kết hợp) của Active Record.

Sau khi đọc bài này, bạn sẽ biết:

* Làm thế nào để khai báo associations giữa các Active Record models.
* Làm thế nào để hiểu các kiểu associations khác nhau Active Record.
* Làm thế nào dùng các methods vào các models của bạn bằng cách tạo associations.

--------------------------------------------------------------------------------

Tại sao dùng Associations?
-----------------

Trong Rails, một _association_ là một liên kết giữa hai Active Record models. 
Tại sao chúng ta cần associations giữa các models? Bởi vì chúng làm các thao tác trở nên đơn giản và dễ dàng hơn
trong mã chương trình của bạn. Ví dụ, xem xét một ứng dụng Rails đơn giản mà nó bao gồm một model
dành cho authors và một model dành cho books. Mỗi author có thể có nhiều books. 
Không có associations, các model được khai báo giống như sau:

```ruby
class Author < ApplicationRecord
end

class Book < ApplicationRecord
end
```

Bây giờ, giả sử chúng ta muốn thêm một book mới dành cho một author đã tồn tại. Chúng ta cần làm như sau:

```ruby
@book = Book.create(published_at: Time.now, author_id: @author.id)
```

Hoặc xem xét xóa một author, và đảm bảo tất cả books của author đó cũng bị xóa theo:

```ruby
@books = Book.where(author_id: @author.id)
@books.each do |book|
  book.destroy
end
@author.destroy
```

Với Active Record associations, chúng ta có thể sắp xếp các hoạt động này và các hoạt động khác bằng cách khai báo với Rails, 
rằng có một kết nối giữa hai models. Sau đây là code dùng để thiết lập giữa authors và books:

```ruby
class Author < ApplicationRecord
  has_many :books, dependent: :destroy
end

class Book < ApplicationRecord
  belongs_to :author
end
```

Với thay đổi này, việc tạo một book mới dành cho một author cụ thể là dễ dàng hơn:

```ruby
@book = @author.books.create(published_at: Time.now)
```

Xóa một author và tất cả books của author đó càng dễ dàng hơn:

```ruby
@author.destroy
```

Để tìm hiểu thêm về các kiểu associations khác, đọc phần tiếp theo của bài hướng dẫn này. 
Tiếp theo đó là một số mẹo và thủ thuật để làm việc với associations, 
và một danh sách tham khảo các methods và options dành cho associations trong Rails.

Kiểu(Types) của Associations
-------------------------

Rails hỗ trợ 6 kiểu của associations:

* `belongs_to`
* `has_one`
* `has_many`
* `has_many :through`
* `has_one :through`
* `has_and_belongs_to_many`

Associations được thực hiện bằng cách dùng kiểu gọi macro, nên bạn có thể khai báo và thêm tính năng vào models của bạn. 
Ví dụ, bằng cách khai báo một model `belongs_to`  một model khác, 
bạn đã cung cấp cho Rails thông tin về [Primary Key(Khóa chính)](https://en.wikipedia.org/wiki/Unique_key)-[Foreign Key(Khóa ngoại)](https://en.wikipedia.org/wiki/Foreign_key) 
giữa các đối tượng của 2 models, và ngoài ra bạn còn có thêm một số các methods tiện ích được thêm vào model của bạn.

Trong bài này, bạn sẽ học làm thế nào để khai báo và dùng các mẫu associations khác nhau. 
Nhưng trước tiên, ở dưới đây sẽ là một giới thiệu nhanh về các tình huống mà mỗi kiểu association thích hợp được sử dụng.

### `belongs_to` Association

Một `belongs_to` association thiết lập một liên kết một-một với model khác, 
sao cho mỗi đối tượng của một model "belongs to" một đối tượng của model khác. 
Ví dụ, nếu ứng dụng của bạn bao gồm authors và books, và mỗi book có thể được gán chính xác bởi một author, 
bạn quyết định khai báo một model book như thế này:

```ruby
class Book < ApplicationRecord
  belongs_to :author
end
```

![belongs_to Association Diagram](images/belongs_to.png)

Lưu ý: `belongs_to` associations _phải_ dùng danh từ số ít. Nếu bạn dùng danh từ số nhiều trong ví dụ trên: `author` association trong `Book` model, 
bạn sẽ nhận được thông báo rằng "uninitialized constant Book::Authors" (hằng Book:Authors là không được khởi tạo). 
Sở dĩ có điều này là vì Rails tự động tham chiếu đến tên class từ tên của association. 
Nếu tên của association được đặt số nhiều sai, thì tên class tham chiếu đến cũng sai theo.

Migration tương ứng có thể giống như sau:

```ruby
class CreateBooks < ActiveRecord::Migration[5.0]
  def change
    create_table :authors do |t|
      t.string :name
      t.timestamps
    end

    create_table :books do |t|
      t.belongs_to :author, index: true
      t.datetime :published_at
      t.timestamps
    end
  end
end
```

### `has_one` Association

Một `has_one` association ngoài ra cũng được thiết lập kiểu liên kết một-một với model khác, 
nhưng với ý nghĩa khác nhau. 
Association này chỉ ra rằng mỗi đối tượng của một model chứa hoặc sở hữu một đối tượng của model khác. 
Ví dụ, nếu mỗi supplier trong ứng dụng của bạn chỉ-có-một account, bạn có thể khai báo supplier model như sau:

```ruby
class Supplier < ApplicationRecord
  has_one :account
end
```

![has_one Association Diagram](images/has_one.png)

Migration tương ứng có thể giống như sau:

```ruby
class CreateSuppliers < ActiveRecord::Migration[5.0]
  def change
    create_table :suppliers do |t|
      t.string :name
      t.timestamps
    end

    create_table :accounts do |t|
      t.belongs_to :supplier, index: true
      t.string :account_number
      t.timestamps
    end
  end
end
```

Phụ thuộc vào trường hợp sử dụng, bạn có thể cần tạo một chỉ mục duy nhất(unique index) và/hoặc
một ràng buộc foreign key trên column supplier dành cho bảng accounts. Trong trường hợp này, 
định nghĩa column sẽ giống như sau:

```ruby
create_table :accounts do |t|
  t.belongs_to :supplier, index: { unique: true }, foreign_key: true
  # ...
end
```

### `has_many` Association

Một `has_many` association chỉ ra một liên kết một-nhiều với model khác. 
Bạn sẽ thường nhìn thấy association này đi kèm với `belongs_to` association. 
Association này chỉ ra rằng mỗi đối tượng của model có 0 hoặc nhiều đối tượng của model khác. Ví dụ, 
trong một ứng dụng chứa authors và books, author sẽ có nhiều books, author model có thể khai báo giống như sau:

```ruby
class Author < ApplicationRecord
  has_many :books
end
```

Lưu ý: Tên của model khác được khai báo kiểu số nhiều khi dùng với `has_many` association.

![has_many Association Diagram](images/has_many.png)

Migration tương ứng có thể giống như sau:

```ruby
class CreateAuthors < ActiveRecord::Migration[5.0]
  def change
    create_table :authors do |t|
      t.string :name
      t.timestamps
    end

    create_table :books do |t|
      t.belongs_to :author, index: true
      t.datetime :published_at
      t.timestamps
    end
  end
end
```

### `has_many :through` Association

Một `has_many :through` association thường được dùng để thiết lập liên kết nhiều-nhiều với model khác. 
Association chỉ ra rằng khai báo model có thể kết hợp 
với 0 hoặc nhiều đối tượng của model khác bằng việc _thông qua_ một model thứ 3. 
Ví dụ, xem xét một bệnh viện nơi các patients lên lịch hẹn với physicians. 
Association liên quan được khai báo giống như sau:

```ruby
class Physician < ApplicationRecord
  has_many :appointments
  has_many :patients, through: :appointments
end

class Appointment < ApplicationRecord
  belongs_to :physician
  belongs_to :patient
end

class Patient < ApplicationRecord
  has_many :appointments
  has_many :physicians, through: :appointments
end
```

![has_many :through Association Diagram](images/has_many_through.png)

Migration tương ứng có thể giống như sau:

```ruby
class CreateAppointments < ActiveRecord::Migration[5.0]
  def change
    create_table :physicians do |t|
      t.string :name
      t.timestamps
    end

    create_table :patients do |t|
      t.string :name
      t.timestamps
    end

    create_table :appointments do |t|
      t.belongs_to :physician, index: true
      t.belongs_to :patient, index: true
      t.datetime :appointment_date
      t.timestamps
    end
  end
end
```

Tập hợp các model có thể join vào(join models) được quản lý thông qua [`has_many` association methods](#has-many-association-reference).
Ví dụ, nếu bạn gán:

```ruby
physician.patients = patients
```

Join models(giao hai model) mới được tạo tự động dành cho các đối tượng mới được liên kết.
Nếu một liên kết từ trước đã bị xóa thì, thì join rows cũng tự động bị xóa.

Cảnh báo: Tự động xóa của join models là trực tiếp, no destroy callbacks are triggered.

`has_many :through` association ngoài ra còn có thể dùng để thiết lập "đường tắt" thông qua `has_many` associations lồng nhau. 
Ví dụ, nếu một document có nhiều sections, và một section có nhiều paragraphs, 
đôi khi bạn có thể muốn lấy một tập hợp đơn giản các paragraphs trong document. bạn có thể thiết lập như sau:

```ruby
class Document < ApplicationRecord
  has_many :sections
  has_many :paragraphs, through: :sections
end

class Section < ApplicationRecord
  belongs_to :document
  has_many :paragraphs
end

class Paragraph < ApplicationRecord
  belongs_to :section
end
```

Với lệnh `through: :sections` được thêm vào, Rails sẽ hiểu được câu lệnh sau:

```ruby
@document.paragraphs
```

### The `has_one :through` Association

Một `has_one :through` association thiết lập một liên kết một-một với model khác. Association này chỉ ra rằng
model khai báo có thể kết hợp với một đối tượng của model khác _thông qua_ model thứ 3.
Ví dụ, nếu mỗi supplier có account, và mỗi account kết hợp với một account history, thì
supplier model có thể giống như sau:

```ruby
class Supplier < ApplicationRecord
  has_one :account
  has_one :account_history, through: :account
end

class Account < ApplicationRecord
  belongs_to :supplier
  has_one :account_history
end

class AccountHistory < ApplicationRecord
  belongs_to :account
end
```

![has_one :through Association Diagram](images/has_one_through.png)

Migration tương ứng có thể giống như sau:

```ruby
class CreateAccountHistories < ActiveRecord::Migration[5.0]
  def change
    create_table :suppliers do |t|
      t.string :name
      t.timestamps
    end

    create_table :accounts do |t|
      t.belongs_to :supplier, index: true
      t.string :account_number
      t.timestamps
    end

    create_table :account_histories do |t|
      t.belongs_to :account, index: true
      t.integer :credit_rating
      t.timestamps
    end
  end
end
```

### `has_and_belongs_to_many` Association

Một `has_and_belongs_to_many` association tạo một liên kết trực tiếp nhiều-nhiều với model khác, 
và không có model nào ở giữa. Ví dụ, nếu ứng dụng của bạn bao gồm assemblies và parts, 
với mỗi assembly có nhiều parts và mỗi part xuất hiện trong nhiều assemblies, bạn có thể khai báo model như thế này:

```ruby
class Assembly < ApplicationRecord
  has_and_belongs_to_many :parts
end

class Part < ApplicationRecord
  has_and_belongs_to_many :assemblies
end
```

![has_and_belongs_to_many Association Diagram](images/habtm.png)

Migration tương ứng có thể giống như sau:

```ruby
class CreateAssembliesAndParts < ActiveRecord::Migration[5.0]
  def change
    create_table :assemblies do |t|
      t.string :name
      t.timestamps
    end

    create_table :parts do |t|
      t.string :part_number
      t.timestamps
    end

    create_table :assemblies_parts, id: false do |t|
      t.belongs_to :assembly, index: true
      t.belongs_to :part, index: true
    end
  end
end
```

### Lựa chọn giữa `belongs_to` và `has_one`

Nếu bạn muốn thiết lập mối quan hệ một-một giữa hai models, 
bạn sẽ cần thêm `belongs_to` cho một model, và `has_one` cho một model khác. Làm thế nào mà bạn biết điều sẽ đặt nó như thế nào?

Điểm khác biệt là nằm ở nơi bạn đặt foreign key (nó đi vào bảng có class khai báo `belongs_to` association), 
nhưng bạn cũng nên suy nghĩ thêm về ý nghĩa của việc cung cấp dữ liệu cho phù hợp.
Ví dụ, ngữ nghĩa của một dữ liệu quan hệ như sau: supplier sở hữu một account mà account ngoài ra chỉ thuộc một supplier. 
Đây là một mối quan hệ được cung cấp chính xác giống như sau:

```ruby
class Supplier < ApplicationRecord
  has_one :account
end

class Account < ApplicationRecord
  belongs_to :supplier
end
```

Migration tương ứng có thể giống như sau:

```ruby
class CreateSuppliers < ActiveRecord::Migration[5.0]
  def change
    create_table :suppliers do |t|
      t.string :name
      t.timestamps
    end

    create_table :accounts do |t|
      t.integer :supplier_id
      t.string  :account_number
      t.timestamps
    end

    add_index :accounts, :supplier_id
  end
end
```

Lưu ý: Dùng `t.integer :supplier_id` làm cho việc đặt tên foreign key rõ ràng hơn. 
Trong phiên bản hiện tại của Rails, bạn có thể trừu tượng việc thi hành chi tiết này bằng `t.references :supplier`.

### Lựa chọn giữa `has_many :through` và `has_and_belongs_to_many`

Rails cung cấp hai phương pháp khác nhau để khai báo mối quan hệ nhiều-nhiều gữa các models. 
Phương pháp đơn giản hơn là dùng `has_and_belongs_to_many`, nó cho phép bạn tạo một association trực tiếp:

```ruby
class Assembly < ApplicationRecord
  has_and_belongs_to_many :parts
end

class Part < ApplicationRecord
  has_and_belongs_to_many :assemblies
end
```

Phương pháp thứ hai để khai báo mối quan hệ nhiều-nhiều là dùng `has_many :through`. 
Phương pháp này tạo association không trực tiếp, thông qua việc join model(giao hai model):

```ruby
class Assembly < ApplicationRecord
  has_many :manifests
  has_many :parts, through: :manifests
end

class Manifest < ApplicationRecord
  belongs_to :assembly
  belongs_to :part
end

class Part < ApplicationRecord
  has_many :manifests
  has_many :assemblies, through: :manifests
end
```

Nguyên tắc đơn giản nhất là bạn nên thiết lập mối quan hệ `has_many :through` 
nếu bạn cần làm việc với mối quan hệ model(model thứ 3) như là một thực thể(entity) độc lập. 
Nếu bạn không cần làm thêm bất cứ điều gì với mối quan hệ model, 
thì nên sử dụng `has_and_belongs_to_many` sẽ đơn giản hơn (mặc dù bạn sẽ cần phải nhớ tạo bảng joining table(bảng giao giữa hai bảng) trong cơ sở dữ liệu).

Bạn nên dùng `has_many :through` nếu bạn cần validations, callbacks hoặc thêm các thuộc tính trên join model(model giao).

### Polymorphic Associations

Hơi nâng cao hơn một chút về associations là _polymorphic association(kết hợp đa hình)_. 
Với polymorphic associations, một model có thể thuộc nhiều hơn một model khác, trên một association duy nhất. 
Ví dụ, Bạn có một picture model mà nó thuộc về một trong hai employee model hoặc a product model. 
Sau đây là cách khai báo:

```ruby
class Picture < ApplicationRecord
  belongs_to :imageable, polymorphic: true
end

class Employee < ApplicationRecord
  has_many :pictures, as: :imageable
end

class Product < ApplicationRecord
  has_many :pictures, as: :imageable
end
```

Bạn có thể nghĩ rằng một khai báo đa hình(polymorphic) `belongs_to` thiết lập một interface cho các model khác có thể dùng. 
Từ một đối tượng của `Employee` model, bạn có thể lấy một tập hợp các pictures: `@employee.pictures`.

Tương tự, bạn có thể lấy `@product.pictures`.

Nếu bạn có một đối tượng của model `Picture`, bạn có thể lấy được parent của nó thông qua `@picture.imageable`. 
Để làm được điều này, bạn cần khai báo cả hai column foreign key và column type trong model 
mà nó khai báo polymorphic interface:

```ruby
class CreatePictures < ActiveRecord::Migration[5.0]
  def change
    create_table :pictures do |t|
      t.string  :name
      t.integer :imageable_id
      t.string  :imageable_type
      t.timestamps
    end

    add_index :pictures, [:imageable_type, :imageable_id]
  end
end
```

Migration này có thể dùng dạng `t.references`:

```ruby
class CreatePictures < ActiveRecord::Migration[5.0]
  def change
    create_table :pictures do |t|
      t.string :name
      t.references :imageable, polymorphic: true, index: true
      t.timestamps
    end
  end
end
```

![Polymorphic Association Diagram](images/polymorphic.png)

### Self Joins

Trong thiết kế một model dữ liệu, đôi khi bạn sẽ nhận ra một model nên có mối quan hệ với chính nó. 
Ví dụ, bạn có thể muốn chứa tất cả các employees trong một model csdl duy nhất, 
nhưng có thể theo dõi các mối quan hệ như giữa manager and subordinates. 
Trong trường hợp này bạn có thể tạo model với self-joining associations:

```ruby
class Employee < ApplicationRecord
  has_many :subordinates, class_name: "Employee",
                          foreign_key: "manager_id"

  belongs_to :manager, class_name: "Employee"
end
```

Với thiết lập này, bạn có thể lấy `@employee.subordinates` và `@employee.manager`.

Trong migrations/schema của bạn, bạn sẽ thêm một references column đến chính bản thân model đó.

```ruby
class CreateEmployees < ActiveRecord::Migration[5.0]
  def change
    create_table :employees do |t|
      t.references :manager, index: true
      t.timestamps
    end
  end
end
```

Mẹo, thủ thuật và các cảnh báo
--------------------------

Dưới đây là một ít điều mà bạn nên biết để sử dụng Active Record associations một cách hiệu quả hợp lý:

* Controlling caching
* Avoiding name collisions
* Updating the schema
* Controlling association scope
* Bi-directional associations

### Controlling Caching

Tất cả các methods association đều được xây dựng xung quanh caching, nó giữ các kết quả truy vấn gần đây nhất để
sử dụng cho các thao tác trong tương lai. Cache thậm chí được chia sẻ giữa các methods. Ví dụ:

```ruby
author.books                 # lấy books từ csdl
author.books.size            # dùng cached đã được lưu của books
author.books.empty?          # dùng cached đã được lưu của books
```

Nhưng nếu bạn muốn tải lại(reload) cached, bởi vì dữ liệu có thể thay đổi vì nguyên nhân nào đó trong ứng dụng? 
Chỉ cần gọi `reload` trên association:

```ruby
author.books                 # lấy books từ csdl
author.books.size            # dùng cached đã được lưu của books
author.books.reload.empty?   # hủy cached đã được lưu của books
                             # và quay lại csdl
```

### Tránh xung đột tên

Bạn không được sử dụng bất kỳ tên nào với associations của bạn. 
Bởi vì việc tạo associations thêm các method với tên của nó vào model, 
sẽ là ý tưởng tệ hại nếu thêm một tên association mà đã được sử dụng với một method của `ActiveRecord::Base`. 
method association có thể ghi đè method cơ sở và làm hỏng mọi thứ. 
Ví dụ, `attributes` hoặc `connection` là các tên không được dùng cho associations.

### Cập nhât lược đồ csdl(Schema)

Associations cực kỳ hữu ích, nhưng chúng không có ma thuật. 
Bạn chịu trách nhiệm duy trì database schema trùng với associations của bạn. 
Trong thực tế, điều này có nghĩa là 2 việc cần làm, tùy thuộc vào loại associations mà bạn đang tạo. 
Dành cho `belongs_to` associations bạn cần tạo foreign keys, 
và `has_and_belongs_to_many` associations bạn cần tạo bảng join thích hợp.

#### Tạo Foreign Keys dành cho `belongs_to` Associations

Khi bạn khai báo một `belongs_to` association, bạn cần tạo foreign keys thích hợp. 
Ví dụ, xem xét model sau:

```ruby
class Book < ApplicationRecord
  belongs_to :author
end
```

Khai báo này cần được sao lưu bằng cách khai báo chính xác foreign key trên bảng books:

```ruby
class CreateBooks < ActiveRecord::Migration[5.0]
  def change
    create_table :books do |t|
      t.datetime :published_at
      t.string   :book_number
      t.integer  :author_id
    end
  end
end
```

Nếu bạn tạo association một thời gian sau khi bạn tạo các model cơ bản, 
bạn cần nhớ tạo một `add_column` migration để cung cấp các foreign key cần thiết.

Một thói quen tốt là nên thêm index trên các foreign key để cải thiện tốc độ
truy vấn và một ràng buộc foreign key để đảm bảo sự toàn vẹn giữ liệu:

```ruby
class CreateBooks < ActiveRecord::Migration[5.0]
  def change
    create_table :books do |t|
      t.datetime :published_at
      t.string   :book_number
      t.integer  :author_id
    end

    add_index :books, :author_id
    add_foreign_key :books, :authors
  end
end
```

#### Tạo bảng join(Join Tables) dành cho `has_and_belongs_to_many` Associations

Nếu bạn tạo một `has_and_belongs_to_many` association, bạn sẽ cần tạo một bảng join. 
Trừ khi tên của bảng join được chỉ định rõ ràng bằng cách dùng `:join_table` option, 
Active Record tạo tên bằng cách sử dụng danh sách từ vựng của tên class. 
Nên giao giữa author và book models sẽ tạo một join tables với tên mặc định là "authors_books" 
bởi vì "a" đứng trước "b" theo thứ tự từ vựng.

Cảnh báo: Độ ưu tiên giữa các tên model được tính toán dùng toán tử `<=>` dành cho chuỗi `String`. 
Điều này có nghĩa là nếu các chuỗi có độ dài khác nhau, 
và các chuỗi đều bằng nhau khi so sánh độ dài nhỏ nhất, 
thì chuỗi dài hơn được xem xét độ ưu tiên cao hơn so với chuỗi có độ dài nhỏ hơn. 
Ví dụ, một bảng "paper_boxes" và "papers" khi join lại với nhau
sẽ tạo ra bảng "papers_paper_boxes" bởi vì độ dài của tên "paper_boxes" lớn hơn, 
nhưng trên thực tế nó sẽ tạo ra một bảng join "paper_boxes_papers" 
  (bởi vì dấu gạch dưới '\_' có thứ tự từ điển _bé_ hơn 's' trong encodings phổ biến).

cho dù có là tên gì thì bạn cũng phải tạo ra migration thích hợp. Ví dụ, xem xét associations:

```ruby
class Assembly < ApplicationRecord
  has_and_belongs_to_many :parts
end

class Part < ApplicationRecord
  has_and_belongs_to_many :assemblies
end
```

Cần được lưu giữ bởi một migration để tạo bảng `assemblies_parts`. Bảng này nên được tạo mà không có primary key:

```ruby
class CreateAssembliesPartsJoinTable < ActiveRecord::Migration[5.0]
  def change
    create_table :assemblies_parts, id: false do |t|
      t.integer :assembly_id
      t.integer :part_id
    end

    add_index :assemblies_parts, :assembly_id
    add_index :assemblies_parts, :part_id
  end
end
```

Chúng ta đặt `id: false` vào `create_table` bởi vì bảng trên không mô tả một model. 
Điều này là bắt buộc để cho các association làm việc đúng. 
Nếu bạn quan sát thấy bất kỳ hành vì kỳ lạ nào trong `has_and_belongs_to_many` association 
như bị đọc sai model IDs, hoặc xung đột exception IDs, có khả năng bạn đã quên điều ở trên.

Ngoài ra bạn có thể dùng method `create_join_table`

```ruby
class CreateAssembliesPartsJoinTable < ActiveRecord::Migration[5.0]
  def change
    create_join_table :assemblies, :parts do |t|
      t.index :assembly_id
      t.index :part_id
    end
  end
end
```

### Kiểm soát phạm vi của Association

Mặc định, associations tìm kiếm các objects chỉ bên trong phạm vi của module hiện tại. 
Điều này có thể quan trọng khi bạn khai báo Active Record models bên trong một module. Ví dụ:

```ruby
module MyApplication
  module Business
    class Supplier < ApplicationRecord
      has_one :account
    end

    class Account < ApplicationRecord
      belongs_to :supplier
    end
  end
end
```

Mẫu trên sẽ làm việc tốt, bởi vì cả hai `Supplier` và `Account` class đều được định nghĩa bên trong cùng scope. 
Nhưng như dưới đây sẽ _không_ làm việc bởi vì `Supplier` và `Account` đều được định nghĩa trong scopes khác nhau:

```ruby
module MyApplication
  module Business
    class Supplier < ApplicationRecord
      has_one :account
    end
  end

  module Billing
    class Account < ApplicationRecord
      belongs_to :supplier
    end
  end
end
```

Associate một model với một model trong một namespace khác, 
bạn phải chỉ rõ tên class đầy đủ trong khai báo association:

```ruby
module MyApplication
  module Business
    class Supplier < ApplicationRecord
      has_one :account,
        class_name: "MyApplication::Billing::Account"
    end
  end

  module Billing
    class Account < ApplicationRecord
      belongs_to :supplier,
        class_name: "MyApplication::Business::Supplier"
    end
  end
end
```

### Associations Hai chiều

Bình thường các Associations làm việc theo hai hướng, yêu cầu khai báo hai models khác nhau:

```ruby
class Author < ApplicationRecord
  has_many :books
end

class Book < ApplicationRecord
  belongs_to :author
end
```

Active Record sẽ cố gắng để tự động xác định rằng hai models chia sẻ một association hai chiều
dựa trên tên của association. Theo cách này, Active Record sẽ chỉ load một bản sao của đối tượng `Author`, 
làm cho ứng dụng của bạn hiệu quả hơn và ngăn ngừa dữ liệu không nhất quán:

```ruby
a = Author.first
b = a.books.first
a.first_name == b.author.first_name # => true
a.first_name = 'David'
a.first_name == b.author.first_name # => true
```

Active Record hỗ trợ tự động xác định dành cho hầu hết các associations với tên chuẩn. 
Tuy nhiên, Active Record sẽ không tự động xác định một associations hai chiều mà nó chứa bất kỳ các options sau:

* `:conditions`
* `:through`
* `:polymorphic`
* `:class_name`
* `:foreign_key`

Ví dụ, xem xét việc khai báo model như sau:

```ruby
class Author < ApplicationRecord
  has_many :books
end

class Book < ApplicationRecord
  belongs_to :writer, class_name: 'Author', foreign_key: 'author_id'
end
```

Active Record sẽ không tự động nhận diện association hai chiều:

```ruby
a = Author.first
b = a.books.first
a.first_name == b.writer.first_name # => true
a.first_name = 'David'
a.first_name == b.writer.first_name # => false
```

Active Record cung cấp `:inverse_of` option nên bạn có thể khai báo associations hai chiều như sau:

```ruby
class Author < ApplicationRecord
  has_many :books, inverse_of: 'writer'
end

class Book < ApplicationRecord
  belongs_to :writer, class_name: 'Author', foreign_key: 'author_id'
end
```

Bằng cách thêm `:inverse_of` option trong khái báo `has_many` association, Active Record 
sẽ biết làm thế nào để nhận diện association hai chiều:

```ruby
a = Author.first
b = a.books.first
a.first_name == b.writer.first_name # => true
a.first_name = 'David'
a.first_name == b.writer.first_name # => true
```

Có một ít giới hạn với `:inverse_of` được hỗ trợ:

* Chúng không làm việc với `:through` associations.
* Chúng không làm việc với `:polymorphic` associations.
* Chúng không làm việc với `:as` associations.

Association tham khảo chi tiết
------------------------------

Sau đây là phần trình bày chi tiết của mỗi association, 
bao gồm các method mà chúng được thêm và các options mà bạn có thể dùng khi khai báo association.

### `belongs_to` Association tham khảo

`belongs_to` association tạo ra một liên kết một-một với model khác. Trong csdl, 
association cho biết rằng class này chứa foreign key. 
Nếu class khác chứa foreign key, 
thì bạn nên dùng `has_one` thay vào đó.

#### Các methods được thêm bởi `belongs_to`

Khi bạn khai báo một `belongs_to` association, class được khai báo tự động nhận 5 method liên quan tới association:

* `association`
* `association=(associate)`
* `build_association(attributes = {})`
* `create_association(attributes = {})`
* `create_association!(attributes = {})`
* `reload_association`

Trong tất cả các methods, `association` được thay thế với các symbol được đặt vào
như là đối số đầu tiên của `belongs_to`. Ví dụ, cho khai báo sau:

```ruby
class Book < ApplicationRecord
  belongs_to :author
end
```

Mỗi đối tượng của `Book` model sẽ có những methods sau:

```ruby
author
author=
build_author
create_author
create_author!
reload_author
```

Lưu ý: khi khởi tạo mới `has_one` hoặc `belongs_to` association bạn phải dùng tiền tố `build_` để 
xây dựng association, thay vì `association.build` được sử dụng cho `has_many` hoặc `has_and_belongs_to_many` associations. 
Để tạo, dùng tiền tố `create_`.

##### `association`

Method `association` trả về một đối tượng đã associated, nếu có. Nếu không có đối tượng nào thì, thì nó trả về rỗng `nil`.

```ruby
@author = @book.author
```

If the associated object has already been retrieved from the database for this object, 
the cached version will be returned. To override this behavior (and force a database read), 
call `#reload_association` on the parent object.

```ruby
@author = @book.reload_author
```

##### `association=(associate)`

The `association=` method assigns an associated object to this object. Behind the scenes, this means extracting the primary key from the associated object and setting this object's foreign key to the same value.

```ruby
@book.author = @author
```

##### `build_association(attributes = {})`

The `build_association` method returns a new object of the associated type. This object will be instantiated from the passed attributes, and the link through this object's foreign key will be set, but the associated object will _not_ yet be saved.

```ruby
@author = @book.build_author(author_number: 123,
                                  author_name: "John Doe")
```

##### `create_association(attributes = {})`

The `create_association` method returns a new object of the associated type. This object will be instantiated from the passed attributes, the link through this object's foreign key will be set, and, once it passes all of the validations specified on the associated model, the associated object _will_ be saved.

```ruby
@author = @book.create_author(author_number: 123,
                                   author_name: "John Doe")
```

##### `create_association!(attributes = {})`

Does the same as `create_association` above, but raises `ActiveRecord::RecordInvalid` if the record is invalid.


#### Options for `belongs_to`

While Rails uses intelligent defaults that will work well in most situations, there may be times when you want to customize the behavior of the `belongs_to` association reference. Such customizations can easily be accomplished by passing options and scope blocks when you create the association. For example, this association uses two such options:

```ruby
class Book < ApplicationRecord
  belongs_to :author, dependent: :destroy,
    counter_cache: true
end
```

The `belongs_to` association supports these options:

* `:autosave`
* `:class_name`
* `:counter_cache`
* `:dependent`
* `:foreign_key`
* `:primary_key`
* `:inverse_of`
* `:polymorphic`
* `:touch`
* `:validate`
* `:optional`

##### `:autosave`

If you set the `:autosave` option to `true`, Rails will save any loaded association members and destroy members that are marked for destruction whenever you save the parent object. Setting `:autosave` to `false` is not the same as not setting the `:autosave` option. If the `:autosave` option is not present, then new associated objects will be saved, but updated associated objects will not be saved.

##### `:class_name`

If the name of the other model cannot be derived from the association name, you can use the `:class_name` option to supply the model name. For example, if a book belongs to an author, but the actual name of the model containing authors is `Patron`, you'd set things up this way:

```ruby
class Book < ApplicationRecord
  belongs_to :author, class_name: "Patron"
end
```

##### `:counter_cache`

The `:counter_cache` option can be used to make finding the number of belonging objects more efficient. Consider these models:

```ruby
class Book < ApplicationRecord
  belongs_to :author
end
class Author < ApplicationRecord
  has_many :books
end
```

With these declarations, asking for the value of `@author.books.size` requires making a call to the database to perform a `COUNT(*)` query. To avoid this call, you can add a counter cache to the _belonging_ model:

```ruby
class Book < ApplicationRecord
  belongs_to :author, counter_cache: true
end
class Author < ApplicationRecord
  has_many :books
end
```

With this declaration, Rails will keep the cache value up to date, and then return that value in response to the `size` method.

Although the `:counter_cache` option is specified on the model that includes
the `belongs_to` declaration, the actual column must be added to the
_associated_ (`has_many`) model. In the case above, you would need to add a
column named `books_count` to the `Author` model.

You can override the default column name by specifying a custom column name in
the `counter_cache` declaration instead of `true`. For example, to use
`count_of_books` instead of `books_count`:

```ruby
class Book < ApplicationRecord
  belongs_to :author, counter_cache: :count_of_books
end
class Author < ApplicationRecord
  has_many :books
end
```

NOTE: You only need to specify the `:counter_cache` option on the `belongs_to`
side of the association.

Counter cache columns are added to the containing model's list of read-only attributes through `attr_readonly`.

##### `:dependent`
If you set the `:dependent` option to:

* `:destroy`, when the object is destroyed, `destroy` will be called on its
associated objects.
* `:delete`, when the object is destroyed, all its associated objects will be
deleted directly from the database without calling their `destroy` method.

WARNING: You should not specify this option on a `belongs_to` association that is connected with a `has_many` association on the other class. Doing so can lead to orphaned records in your database.

##### `:foreign_key`

By convention, Rails assumes that the column used to hold the foreign key on this model is the name of the association with the suffix `_id` added. The `:foreign_key` option lets you set the name of the foreign key directly:

```ruby
class Book < ApplicationRecord
  belongs_to :author, class_name: "Patron",
                        foreign_key: "patron_id"
end
```

TIP: In any case, Rails will not create foreign key columns for you. You need to explicitly define them as part of your migrations.

##### `:primary_key`

By convention, Rails assumes that the `id` column is used to hold the primary key
of its tables. The `:primary_key` option allows you to specify a different column.

For example, given we have a `users` table with `guid` as the primary key. If we want a separate `todos` table to hold the foreign key `user_id` in the `guid` column, then we can use `primary_key` to achieve this like so:

```ruby
class User < ApplicationRecord
  self.primary_key = 'guid' # primary key is guid and not id
end

class Todo < ApplicationRecord
  belongs_to :user, primary_key: 'guid'
end
```

When we execute `@user.todos.create` then the `@todo` record will have its
`user_id` value as the `guid` value of `@user`.

##### `:inverse_of`

The `:inverse_of` option specifies the name of the `has_many` or `has_one` association that is the inverse of this association. Does not work in combination with the `:polymorphic` options.

```ruby
class Author < ApplicationRecord
  has_many :books, inverse_of: :author
end

class Book < ApplicationRecord
  belongs_to :author, inverse_of: :books
end
```

##### `:polymorphic`

Passing `true` to the `:polymorphic` option indicates that this is a polymorphic association. Polymorphic associations were discussed in detail <a href="#polymorphic-associations">earlier in this guide</a>.

##### `:touch`

If you set the `:touch` option to `true`, then the `updated_at` or `updated_on` timestamp on the associated object will be set to the current time whenever this object is saved or destroyed:

```ruby
class Book < ApplicationRecord
  belongs_to :author, touch: true
end

class Author < ApplicationRecord
  has_many :books
end
```

In this case, saving or destroying a book will update the timestamp on the associated author. You can also specify a particular timestamp attribute to update:

```ruby
class Book < ApplicationRecord
  belongs_to :author, touch: :books_updated_at
end
```

##### `:validate`

If you set the `:validate` option to `true`, then associated objects will be validated whenever you save this object. By default, this is `false`: associated objects will not be validated when this object is saved.

##### `:optional`

If you set the `:optional` option to `true`, then the presence of the associated
object won't be validated. By default, this option is set to `false`.

#### Scopes for `belongs_to`

There may be times when you wish to customize the query used by `belongs_to`. Such customizations can be achieved via a scope block. For example:

```ruby
class Book < ApplicationRecord
  belongs_to :author, -> { where active: true },
                        dependent: :destroy
end
```

You can use any of the standard [querying methods](active_record_querying.html) inside the scope block. The following ones are discussed below:

* `where`
* `includes`
* `readonly`
* `select`

##### `where`

The `where` method lets you specify the conditions that the associated object must meet.

```ruby
class book < ApplicationRecord
  belongs_to :author, -> { where active: true }
end
```

##### `includes`

You can use the `includes` method to specify second-order associations that should be eager-loaded when this association is used. For example, consider these models:

```ruby
class LineItem < ApplicationRecord
  belongs_to :book
end

class Book < ApplicationRecord
  belongs_to :author
  has_many :line_items
end

class Author < ApplicationRecord
  has_many :books
end
```

If you frequently retrieve authors directly from line items (`@line_item.book.author`), then you can make your code somewhat more efficient by including authors in the association from line items to books:

```ruby
class LineItem < ApplicationRecord
  belongs_to :book, -> { includes :author }
end

class Book < ApplicationRecord
  belongs_to :author
  has_many :line_items
end

class Author < ApplicationRecord
  has_many :books
end
```

NOTE: There's no need to use `includes` for immediate associations - that is, if you have `Book belongs_to :author`, then the author is eager-loaded automatically when it's needed.

##### `readonly`

If you use `readonly`, then the associated object will be read-only when retrieved via the association.

##### `select`

The `select` method lets you override the SQL `SELECT` clause that is used to retrieve data about the associated object. By default, Rails retrieves all columns.

TIP: If you use the `select` method on a `belongs_to` association, you should also set the `:foreign_key` option to guarantee the correct results.

#### Do Any Associated Objects Exist?

You can see if any associated objects exist by using the `association.nil?` method:

```ruby
if @book.author.nil?
  @msg = "No author found for this book"
end
```

#### When are Objects Saved?

Assigning an object to a `belongs_to` association does _not_ automatically save the object. It does not save the associated object either.

### `has_one` Association Reference

The `has_one` association creates a one-to-one match with another model. In database terms, this association says that the other class contains the foreign key. If this class contains the foreign key, then you should use `belongs_to` instead.

#### Methods Added by `has_one`

When you declare a `has_one` association, the declaring class automatically gains five methods related to the association:

* `association`
* `association=(associate)`
* `build_association(attributes = {})`
* `create_association(attributes = {})`
* `create_association!(attributes = {})`
* `reload_association`

In all of these methods, `association` is replaced with the symbol passed as the first argument to `has_one`. For example, given the declaration:

```ruby
class Supplier < ApplicationRecord
  has_one :account
end
```

Each instance of the `Supplier` model will have these methods:

```ruby
account
account=
build_account
create_account
create_account!
reload_account
```

NOTE: When initializing a new `has_one` or `belongs_to` association you must use the `build_` prefix to build the association, rather than the `association.build` method that would be used for `has_many` or `has_and_belongs_to_many` associations. To create one, use the `create_` prefix.

##### `association`

The `association` method returns the associated object, if any. If no associated object is found, it returns `nil`.

```ruby
@account = @supplier.account
```

If the associated object has already been retrieved from the database for this object, the cached version will be returned. To override this behavior (and force a database read), call `#reload_association` on the parent object.

```ruby
@account = @supplier.reload_account
```

##### `association=(associate)`

The `association=` method assigns an associated object to this object. Behind the scenes, this means extracting the primary key from this object and setting the associated object's foreign key to the same value.

```ruby
@supplier.account = @account
```

##### `build_association(attributes = {})`

The `build_association` method returns a new object of the associated type. This object will be instantiated from the passed attributes, and the link through its foreign key will be set, but the associated object will _not_ yet be saved.

```ruby
@account = @supplier.build_account(terms: "Net 30")
```

##### `create_association(attributes = {})`

The `create_association` method returns a new object of the associated type. This object will be instantiated from the passed attributes, the link through its foreign key will be set, and, once it passes all of the validations specified on the associated model, the associated object _will_ be saved.

```ruby
@account = @supplier.create_account(terms: "Net 30")
```

##### `create_association!(attributes = {})`

Does the same as `create_association` above, but raises `ActiveRecord::RecordInvalid` if the record is invalid.

#### Options for `has_one`

While Rails uses intelligent defaults that will work well in most situations, there may be times when you want to customize the behavior of the `has_one` association reference. Such customizations can easily be accomplished by passing options when you create the association. For example, this association uses two such options:

```ruby
class Supplier < ApplicationRecord
  has_one :account, class_name: "Billing", dependent: :nullify
end
```

The `has_one` association supports these options:

* `:as`
* `:autosave`
* `:class_name`
* `:dependent`
* `:foreign_key`
* `:inverse_of`
* `:primary_key`
* `:source`
* `:source_type`
* `:through`
* `:validate`

##### `:as`

Setting the `:as` option indicates that this is a polymorphic association. Polymorphic associations were discussed in detail [earlier in this guide](#polymorphic-associations).

##### `:autosave`

If you set the `:autosave` option to `true`, Rails will save any loaded association members and destroy members that are marked for destruction whenever you save the parent object. Setting `:autosave` to `false` is not the same as not setting the `:autosave` option. If the `:autosave` option is not present, then new associated objects will be saved, but updated associated objects will not be saved.

##### `:class_name`

If the name of the other model cannot be derived from the association name, you can use the `:class_name` option to supply the model name. For example, if a supplier has an account, but the actual name of the model containing accounts is `Billing`, you'd set things up this way:

```ruby
class Supplier < ApplicationRecord
  has_one :account, class_name: "Billing"
end
```

##### `:dependent`

Controls what happens to the associated object when its owner is destroyed:

* `:destroy` causes the associated object to also be destroyed
* `:delete` causes the associated object to be deleted directly from the database (so callbacks will not execute)
* `:nullify` causes the foreign key to be set to `NULL`. Callbacks are not executed.
* `:restrict_with_exception` causes an exception to be raised if there is an associated record
* `:restrict_with_error` causes an error to be added to the owner if there is an associated object

It's necessary not to set or leave `:nullify` option for those associations
that have `NOT NULL` database constraints. If you don't set `dependent` to
destroy such associations you won't be able to change the associated object
because the initial associated object's foreign key will be set to the
unallowed `NULL` value.

##### `:foreign_key`

By convention, Rails assumes that the column used to hold the foreign key on the other model is the name of this model with the suffix `_id` added. The `:foreign_key` option lets you set the name of the foreign key directly:

```ruby
class Supplier < ApplicationRecord
  has_one :account, foreign_key: "supp_id"
end
```

TIP: In any case, Rails will not create foreign key columns for you. You need to explicitly define them as part of your migrations.

##### `:inverse_of`

The `:inverse_of` option specifies the name of the `belongs_to` association that is the inverse of this association. Does not work in combination with the `:through` or `:as` options.

```ruby
class Supplier < ApplicationRecord
  has_one :account, inverse_of: :supplier
end

class Account < ApplicationRecord
  belongs_to :supplier, inverse_of: :account
end
```

##### `:primary_key`

By convention, Rails assumes that the column used to hold the primary key of this model is `id`. You can override this and explicitly specify the primary key with the `:primary_key` option.

##### `:source`

The `:source` option specifies the source association name for a `has_one :through` association.

##### `:source_type`

The `:source_type` option specifies the source association type for a `has_one :through` association that proceeds through a polymorphic association.

##### `:through`

The `:through` option specifies a join model through which to perform the query. `has_one :through` associations were discussed in detail [earlier in this guide](#the-has-one-through-association).

##### `:validate`

If you set the `:validate` option to `true`, then associated objects will be validated whenever you save this object. By default, this is `false`: associated objects will not be validated when this object is saved.

#### Scopes for `has_one`

There may be times when you wish to customize the query used by `has_one`. Such customizations can be achieved via a scope block. For example:

```ruby
class Supplier < ApplicationRecord
  has_one :account, -> { where active: true }
end
```

You can use any of the standard [querying methods](active_record_querying.html) inside the scope block. The following ones are discussed below:

* `where`
* `includes`
* `readonly`
* `select`

##### `where`

The `where` method lets you specify the conditions that the associated object must meet.

```ruby
class Supplier < ApplicationRecord
  has_one :account, -> { where "confirmed = 1" }
end
```

##### `includes`

You can use the `includes` method to specify second-order associations that should be eager-loaded when this association is used. For example, consider these models:

```ruby
class Supplier < ApplicationRecord
  has_one :account
end

class Account < ApplicationRecord
  belongs_to :supplier
  belongs_to :representative
end

class Representative < ApplicationRecord
  has_many :accounts
end
```

If you frequently retrieve representatives directly from suppliers (`@supplier.account.representative`), then you can make your code somewhat more efficient by including representatives in the association from suppliers to accounts:

```ruby
class Supplier < ApplicationRecord
  has_one :account, -> { includes :representative }
end

class Account < ApplicationRecord
  belongs_to :supplier
  belongs_to :representative
end

class Representative < ApplicationRecord
  has_many :accounts
end
```

##### `readonly`

If you use the `readonly` method, then the associated object will be read-only when retrieved via the association.

##### `select`

The `select` method lets you override the SQL `SELECT` clause that is used to retrieve data about the associated object. By default, Rails retrieves all columns.

#### Do Any Associated Objects Exist?

You can see if any associated objects exist by using the `association.nil?` method:

```ruby
if @supplier.account.nil?
  @msg = "No account found for this supplier"
end
```

#### When are Objects Saved?

When you assign an object to a `has_one` association, that object is automatically saved (in order to update its foreign key). In addition, any object being replaced is also automatically saved, because its foreign key will change too.

If either of these saves fails due to validation errors, then the assignment statement returns `false` and the assignment itself is cancelled.

If the parent object (the one declaring the `has_one` association) is unsaved (that is, `new_record?` returns `true`) then the child objects are not saved. They will automatically when the parent object is saved.

If you want to assign an object to a `has_one` association without saving the object, use the `build_association` method.

### `has_many` Association Reference

The `has_many` association creates a one-to-many relationship with another model. In database terms, this association says that the other class will have a foreign key that refers to instances of this class.

#### Methods Added by `has_many`

When you declare a `has_many` association, the declaring class automatically gains 16 methods related to the association:

* `collection`
* `collection<<(object, ...)`
* `collection.delete(object, ...)`
* `collection.destroy(object, ...)`
* `collection=(objects)`
* `collection_singular_ids`
* `collection_singular_ids=(ids)`
* `collection.clear`
* `collection.empty?`
* `collection.size`
* `collection.find(...)`
* `collection.where(...)`
* `collection.exists?(...)`
* `collection.build(attributes = {}, ...)`
* `collection.create(attributes = {})`
* `collection.create!(attributes = {})`
* `collection.reload`

In all of these methods, `collection` is replaced with the symbol passed as the first argument to `has_many`, and `collection_singular` is replaced with the singularized version of that symbol. For example, given the declaration:

```ruby
class Author < ApplicationRecord
  has_many :books
end
```

Each instance of the `Author` model will have these methods:

```ruby
books
books<<(object, ...)
books.delete(object, ...)
books.destroy(object, ...)
books=(objects)
book_ids
book_ids=(ids)
books.clear
books.empty?
books.size
books.find(...)
books.where(...)
books.exists?(...)
books.build(attributes = {}, ...)
books.create(attributes = {})
books.create!(attributes = {})
books.reload
```

##### `collection`

The `collection` method returns a Relation of all of the associated objects. If there are no associated objects, it returns an empty Relation.

```ruby
@books = @author.books
```

##### `collection<<(object, ...)`

The `collection<<` method adds one or more objects to the collection by setting their foreign keys to the primary key of the calling model.

```ruby
@author.books << @book1
```

##### `collection.delete(object, ...)`

The `collection.delete` method removes one or more objects from the collection by setting their foreign keys to `NULL`.

```ruby
@author.books.delete(@book1)
```

WARNING: Additionally, objects will be destroyed if they're associated with `dependent: :destroy`, and deleted if they're associated with `dependent: :delete_all`.

##### `collection.destroy(object, ...)`

The `collection.destroy` method removes one or more objects from the collection by running `destroy` on each object.

```ruby
@author.books.destroy(@book1)
```

WARNING: Objects will _always_ be removed from the database, ignoring the `:dependent` option.

##### `collection=(objects)`

The `collection=` method makes the collection contain only the supplied objects, by adding and deleting as appropriate. The changes are persisted to the database.

##### `collection_singular_ids`

The `collection_singular_ids` method returns an array of the ids of the objects in the collection.

```ruby
@book_ids = @author.book_ids
```

##### `collection_singular_ids=(ids)`

The `collection_singular_ids=` method makes the collection contain only the objects identified by the supplied primary key values, by adding and deleting as appropriate. The changes are persisted to the database.

##### `collection.clear`

The `collection.clear` method removes all objects from the collection according to the strategy specified by the `dependent` option. If no option is given, it follows the default strategy. The default strategy for `has_many :through` associations is `delete_all`, and for `has_many` associations is to set the foreign keys to `NULL`.

```ruby
@author.books.clear
```

WARNING: Objects will be deleted if they're associated with `dependent: :destroy`,
just like `dependent: :delete_all`.

##### `collection.empty?`

The `collection.empty?` method returns `true` if the collection does not contain any associated objects.

```erb
<% if @author.books.empty? %>
  No Books Found
<% end %>
```

##### `collection.size`

The `collection.size` method returns the number of objects in the collection.

```ruby
@book_count = @author.books.size
```

##### `collection.find(...)`

The `collection.find` method finds objects within the collection. It uses the same syntax and options as
[`ActiveRecord::Base.find`](http://api.rubyonrails.org/classes/ActiveRecord/FinderMethods.html#method-i-find).

```ruby
@available_book = @author.books.find(1)
```

##### `collection.where(...)`

The `collection.where` method finds objects within the collection based on the conditions supplied but the objects are loaded lazily meaning that the database is queried only when the object(s) are accessed.

```ruby
@available_books = @author.books.where(available: true) # No query yet
@available_book = @available_books.first # Now the database will be queried
```

##### `collection.exists?(...)`

The `collection.exists?` method checks whether an object meeting the supplied
conditions exists in the collection. It uses the same syntax and options as
[`ActiveRecord::Base.exists?`](http://api.rubyonrails.org/classes/ActiveRecord/FinderMethods.html#method-i-exists-3F).

##### `collection.build(attributes = {}, ...)`

The `collection.build` method returns a single or array of new objects of the associated type. The object(s) will be instantiated from the passed attributes, and the link through their foreign key will be created, but the associated objects will _not_ yet be saved.

```ruby
@book = @author.books.build(published_at: Time.now,
                                book_number: "A12345")

@books = @author.books.build([
  { published_at: Time.now, book_number: "A12346" },
  { published_at: Time.now, book_number: "A12347" }
])
```

##### `collection.create(attributes = {})`

The `collection.create` method returns a single or array of new objects of the associated type. The object(s) will be instantiated from the passed attributes, the link through its foreign key will be created, and, once it passes all of the validations specified on the associated model, the associated object _will_ be saved.

```ruby
@book = @author.books.create(published_at: Time.now,
                                 book_number: "A12345")

@books = @author.books.create([
  { published_at: Time.now, book_number: "A12346" },
  { published_at: Time.now, book_number: "A12347" }
])
```

##### `collection.create!(attributes = {})`

Does the same as `collection.create` above, but raises `ActiveRecord::RecordInvalid` if the record is invalid.

##### `collection.reload`

The `collection.reload` method returns a Relation of all of the associated objects, forcing a database read. If there are no associated objects, it returns an empty Relation.

```ruby
@books = @author.books.reload
```

#### Options for `has_many`

While Rails uses intelligent defaults that will work well in most situations, there may be times when you want to customize the behavior of the `has_many` association reference. Such customizations can easily be accomplished by passing options when you create the association. For example, this association uses two such options:

```ruby
class Author < ApplicationRecord
  has_many :books, dependent: :delete_all, validate: false
end
```

The `has_many` association supports these options:

* `:as`
* `:autosave`
* `:class_name`
* `:counter_cache`
* `:dependent`
* `:foreign_key`
* `:inverse_of`
* `:primary_key`
* `:source`
* `:source_type`
* `:through`
* `:validate`

##### `:as`

Setting the `:as` option indicates that this is a polymorphic association, as discussed [earlier in this guide](#polymorphic-associations).

##### `:autosave`

If you set the `:autosave` option to `true`, Rails will save any loaded association members and destroy members that are marked for destruction whenever you save the parent object. Setting `:autosave` to `false` is not the same as not setting the `:autosave` option. If the `:autosave` option is not present, then new associated objects will be saved, but updated associated objects will not be saved.

##### `:class_name`

If the name of the other model cannot be derived from the association name, you can use the `:class_name` option to supply the model name. For example, if an author has many books, but the actual name of the model containing books is `Transaction`, you'd set things up this way:

```ruby
class Author < ApplicationRecord
  has_many :books, class_name: "Transaction"
end
```

##### `:counter_cache`

This option can be used to configure a custom named `:counter_cache`. You only need this option when you customized the name of your `:counter_cache` on the [belongs_to association](#options-for-belongs-to).

##### `:dependent`

Controls what happens to the associated objects when their owner is destroyed:

* `:destroy` causes all the associated objects to also be destroyed
* `:delete_all` causes all the associated objects to be deleted directly from the database (so callbacks will not execute)
* `:nullify` causes the foreign keys to be set to `NULL`. Callbacks are not executed.
* `:restrict_with_exception` causes an exception to be raised if there are any associated records
* `:restrict_with_error` causes an error to be added to the owner if there are any associated objects

##### `:foreign_key`

By convention, Rails assumes that the column used to hold the foreign key on the other model is the name of this model with the suffix `_id` added. The `:foreign_key` option lets you set the name of the foreign key directly:

```ruby
class Author < ApplicationRecord
  has_many :books, foreign_key: "cust_id"
end
```

TIP: In any case, Rails will not create foreign key columns for you. You need to explicitly define them as part of your migrations.

##### `:inverse_of`

The `:inverse_of` option specifies the name of the `belongs_to` association that is the inverse of this association. Does not work in combination with the `:through` or `:as` options.

```ruby
class Author < ApplicationRecord
  has_many :books, inverse_of: :author
end

class Book < ApplicationRecord
  belongs_to :author, inverse_of: :books
end
```

##### `:primary_key`

By convention, Rails assumes that the column used to hold the primary key of the association is `id`. You can override this and explicitly specify the primary key with the `:primary_key` option.

Let's say the `users` table has `id` as the primary_key but it also
has a `guid` column. The requirement is that the `todos` table should
hold the `guid` column value as the foreign key and not `id`
value. This can be achieved like this:

```ruby
class User < ApplicationRecord
  has_many :todos, primary_key: :guid
end
```

Now if we execute `@todo = @user.todos.create` then the `@todo`
record's `user_id` value will be the `guid` value of `@user`.


##### `:source`

The `:source` option specifies the source association name for a `has_many :through` association. You only need to use this option if the name of the source association cannot be automatically inferred from the association name.

##### `:source_type`

The `:source_type` option specifies the source association type for a `has_many :through` association that proceeds through a polymorphic association.

##### `:through`

The `:through` option specifies a join model through which to perform the query. `has_many :through` associations provide a way to implement many-to-many relationships, as discussed [earlier in this guide](#the-has-many-through-association).

##### `:validate`

If you set the `:validate` option to `false`, then associated objects will not be validated whenever you save this object. By default, this is `true`: associated objects will be validated when this object is saved.

#### Scopes for `has_many`

There may be times when you wish to customize the query used by `has_many`. Such customizations can be achieved via a scope block. For example:

```ruby
class Author < ApplicationRecord
  has_many :books, -> { where processed: true }
end
```

You can use any of the standard [querying methods](active_record_querying.html) inside the scope block. The following ones are discussed below:

* `where`
* `extending`
* `group`
* `includes`
* `limit`
* `offset`
* `order`
* `readonly`
* `select`
* `distinct`

##### `where`

The `where` method lets you specify the conditions that the associated object must meet.

```ruby
class Author < ApplicationRecord
  has_many :confirmed_books, -> { where "confirmed = 1" },
    class_name: "Book"
end
```

You can also set conditions via a hash:

```ruby
class Author < ApplicationRecord
  has_many :confirmed_books, -> { where confirmed: true },
                              class_name: "Book"
end
```

If you use a hash-style `where` option, then record creation via this association will be automatically scoped using the hash. In this case, using `@author.confirmed_books.create` or `@author.confirmed_books.build` will create books where the confirmed column has the value `true`.

##### `extending`

The `extending` method specifies a named module to extend the association proxy. Association extensions are discussed in detail [later in this guide](#association-extensions).

##### `group`

The `group` method supplies an attribute name to group the result set by, using a `GROUP BY` clause in the finder SQL.

```ruby
class Author < ApplicationRecord
  has_many :line_items, -> { group 'books.id' },
                        through: :books
end
```

##### `includes`

You can use the `includes` method to specify second-order associations that should be eager-loaded when this association is used. For example, consider these models:

```ruby
class Author < ApplicationRecord
  has_many :books
end

class Book < ApplicationRecord
  belongs_to :author
  has_many :line_items
end

class LineItem < ApplicationRecord
  belongs_to :book
end
```

If you frequently retrieve line items directly from authors (`@author.books.line_items`), then you can make your code somewhat more efficient by including line items in the association from authors to books:

```ruby
class Author < ApplicationRecord
  has_many :books, -> { includes :line_items }
end

class Book < ApplicationRecord
  belongs_to :author
  has_many :line_items
end

class LineItem < ApplicationRecord
  belongs_to :book
end
```

##### `limit`

The `limit` method lets you restrict the total number of objects that will be fetched through an association.

```ruby
class Author < ApplicationRecord
  has_many :recent_books,
    -> { order('published_at desc').limit(100) },
    class_name: "Book"
end
```

##### `offset`

The `offset` method lets you specify the starting offset for fetching objects via an association. For example, `-> { offset(11) }` will skip the first 11 records.

##### `order`

The `order` method dictates the order in which associated objects will be received (in the syntax used by an SQL `ORDER BY` clause).

```ruby
class Author < ApplicationRecord
  has_many :books, -> { order "date_confirmed DESC" }
end
```

##### `readonly`

If you use the `readonly` method, then the associated objects will be read-only when retrieved via the association.

##### `select`

The `select` method lets you override the SQL `SELECT` clause that is used to retrieve data about the associated objects. By default, Rails retrieves all columns.

WARNING: If you specify your own `select`, be sure to include the primary key and foreign key columns of the associated model. If you do not, Rails will throw an error.

##### `distinct`

Use the `distinct` method to keep the collection free of duplicates. This is
mostly useful together with the `:through` option.

```ruby
class Person < ApplicationRecord
  has_many :readings
  has_many :articles, through: :readings
end

person = Person.create(name: 'John')
article   = Article.create(name: 'a1')
person.articles << article
person.articles << article
person.articles.inspect # => [#<Article id: 5, name: "a1">, #<Article id: 5, name: "a1">]
Reading.all.inspect     # => [#<Reading id: 12, person_id: 5, article_id: 5>, #<Reading id: 13, person_id: 5, article_id: 5>]
```

In the above case there are two readings and `person.articles` brings out both of
them even though these records are pointing to the same article.

Now let's set `distinct`:

```ruby
class Person
  has_many :readings
  has_many :articles, -> { distinct }, through: :readings
end

person = Person.create(name: 'Honda')
article   = Article.create(name: 'a1')
person.articles << article
person.articles << article
person.articles.inspect # => [#<Article id: 7, name: "a1">]
Reading.all.inspect     # => [#<Reading id: 16, person_id: 7, article_id: 7>, #<Reading id: 17, person_id: 7, article_id: 7>]
```

In the above case there are still two readings. However `person.articles` shows
only one article because the collection loads only unique records.

If you want to make sure that, upon insertion, all of the records in the
persisted association are distinct (so that you can be sure that when you
inspect the association that you will never find duplicate records), you should
add a unique index on the table itself. For example, if you have a table named
`readings` and you want to make sure the articles can only be added to a person once,
you could add the following in a migration:

```ruby
add_index :readings, [:person_id, :article_id], unique: true
```

Once you have this unique index, attempting to add the article to a person twice
will raise an `ActiveRecord::RecordNotUnique` error:

```ruby
person = Person.create(name: 'Honda')
article = Article.create(name: 'a1')
person.articles << article
person.articles << article # => ActiveRecord::RecordNotUnique
```

Note that checking for uniqueness using something like `include?` is subject
to race conditions. Do not attempt to use `include?` to enforce distinctness
in an association. For instance, using the article example from above, the
following code would be racy because multiple users could be attempting this
at the same time:

```ruby
person.articles << article unless person.articles.include?(article)
```

#### When are Objects Saved?

When you assign an object to a `has_many` association, that object is automatically saved (in order to update its foreign key). If you assign multiple objects in one statement, then they are all saved.

If any of these saves fails due to validation errors, then the assignment statement returns `false` and the assignment itself is cancelled.

If the parent object (the one declaring the `has_many` association) is unsaved (that is, `new_record?` returns `true`) then the child objects are not saved when they are added. All unsaved members of the association will automatically be saved when the parent is saved.

If you want to assign an object to a `has_many` association without saving the object, use the `collection.build` method.

### `has_and_belongs_to_many` Association Reference

The `has_and_belongs_to_many` association creates a many-to-many relationship with another model. In database terms, this associates two classes via an intermediate join table that includes foreign keys referring to each of the classes.

#### Methods Added by `has_and_belongs_to_many`

When you declare a `has_and_belongs_to_many` association, the declaring class automatically gains 16 methods related to the association:

* `collection`
* `collection<<(object, ...)`
* `collection.delete(object, ...)`
* `collection.destroy(object, ...)`
* `collection=(objects)`
* `collection_singular_ids`
* `collection_singular_ids=(ids)`
* `collection.clear`
* `collection.empty?`
* `collection.size`
* `collection.find(...)`
* `collection.where(...)`
* `collection.exists?(...)`
* `collection.build(attributes = {})`
* `collection.create(attributes = {})`
* `collection.create!(attributes = {})`
* `collection.reload`

In all of these methods, `collection` is replaced with the symbol passed as the first argument to `has_and_belongs_to_many`, and `collection_singular` is replaced with the singularized version of that symbol. For example, given the declaration:

```ruby
class Part < ApplicationRecord
  has_and_belongs_to_many :assemblies
end
```

Each instance of the `Part` model will have these methods:

```ruby
assemblies
assemblies<<(object, ...)
assemblies.delete(object, ...)
assemblies.destroy(object, ...)
assemblies=(objects)
assembly_ids
assembly_ids=(ids)
assemblies.clear
assemblies.empty?
assemblies.size
assemblies.find(...)
assemblies.where(...)
assemblies.exists?(...)
assemblies.build(attributes = {}, ...)
assemblies.create(attributes = {})
assemblies.create!(attributes = {})
assemblies.reload
```

##### Additional Column Methods

If the join table for a `has_and_belongs_to_many` association has additional columns beyond the two foreign keys, these columns will be added as attributes to records retrieved via that association. Records returned with additional attributes will always be read-only, because Rails cannot save changes to those attributes.

WARNING: The use of extra attributes on the join table in a `has_and_belongs_to_many` association is deprecated. If you require this sort of complex behavior on the table that joins two models in a many-to-many relationship, you should use a `has_many :through` association instead of `has_and_belongs_to_many`.


##### `collection`

The `collection` method returns a Relation of all of the associated objects. If there are no associated objects, it returns an empty Relation.

```ruby
@assemblies = @part.assemblies
```

##### `collection<<(object, ...)`

The `collection<<` method adds one or more objects to the collection by creating records in the join table.

```ruby
@part.assemblies << @assembly1
```

NOTE: This method is aliased as `collection.concat` and `collection.push`.

##### `collection.delete(object, ...)`

The `collection.delete` method removes one or more objects from the collection by deleting records in the join table. This does not destroy the objects.

```ruby
@part.assemblies.delete(@assembly1)
```

##### `collection.destroy(object, ...)`

The `collection.destroy` method removes one or more objects from the collection by deleting records in the join table. This does not destroy the objects.

```ruby
@part.assemblies.destroy(@assembly1)
```

##### `collection=(objects)`

The `collection=` method makes the collection contain only the supplied objects, by adding and deleting as appropriate. The changes are persisted to the database.

##### `collection_singular_ids`

The `collection_singular_ids` method returns an array of the ids of the objects in the collection.

```ruby
@assembly_ids = @part.assembly_ids
```

##### `collection_singular_ids=(ids)`

The `collection_singular_ids=` method makes the collection contain only the objects identified by the supplied primary key values, by adding and deleting as appropriate. The changes are persisted to the database.

##### `collection.clear`

The `collection.clear` method removes every object from the collection by deleting the rows from the joining table. This does not destroy the associated objects.

##### `collection.empty?`

The `collection.empty?` method returns `true` if the collection does not contain any associated objects.

```ruby
<% if @part.assemblies.empty? %>
  This part is not used in any assemblies
<% end %>
```

##### `collection.size`

The `collection.size` method returns the number of objects in the collection.

```ruby
@assembly_count = @part.assemblies.size
```

##### `collection.find(...)`

The `collection.find` method finds objects within the collection. It uses the same syntax and options as
[`ActiveRecord::Base.find`](http://api.rubyonrails.org/classes/ActiveRecord/FinderMethods.html#method-i-find).

```ruby
@assembly = @part.assemblies.find(1)
```

##### `collection.where(...)`

The `collection.where` method finds objects within the collection based on the conditions supplied but the objects are loaded lazily meaning that the database is queried only when the object(s) are accessed.

```ruby
@new_assemblies = @part.assemblies.where("created_at > ?", 2.days.ago)
```

##### `collection.exists?(...)`

The `collection.exists?` method checks whether an object meeting the supplied
conditions exists in the collection. It uses the same syntax and options as
[`ActiveRecord::Base.exists?`](http://api.rubyonrails.org/classes/ActiveRecord/FinderMethods.html#method-i-exists-3F).

##### `collection.build(attributes = {})`

The `collection.build` method returns a new object of the associated type. This object will be instantiated from the passed attributes, and the link through the join table will be created, but the associated object will _not_ yet be saved.

```ruby
@assembly = @part.assemblies.build({assembly_name: "Transmission housing"})
```

##### `collection.create(attributes = {})`

The `collection.create` method returns a new object of the associated type. This object will be instantiated from the passed attributes, the link through the join table will be created, and, once it passes all of the validations specified on the associated model, the associated object _will_ be saved.

```ruby
@assembly = @part.assemblies.create({assembly_name: "Transmission housing"})
```

##### `collection.create!(attributes = {})`

Does the same as `collection.create`, but raises `ActiveRecord::RecordInvalid` if the record is invalid.

##### `collection.reload`

The `collection.reload` method returns a Relation of all of the associated objects, forcing a database read. If there are no associated objects, it returns an empty Relation.

```ruby
@assemblies = @part.assemblies.reload
```

#### Options for `has_and_belongs_to_many`

While Rails uses intelligent defaults that will work well in most situations, there may be times when you want to customize the behavior of the `has_and_belongs_to_many` association reference. Such customizations can easily be accomplished by passing options when you create the association. For example, this association uses two such options:

```ruby
class Parts < ApplicationRecord
  has_and_belongs_to_many :assemblies, -> { readonly },
                                       autosave: true
end
```

The `has_and_belongs_to_many` association supports these options:

* `:association_foreign_key`
* `:autosave`
* `:class_name`
* `:foreign_key`
* `:join_table`
* `:validate`

##### `:association_foreign_key`

By convention, Rails assumes that the column in the join table used to hold the foreign key pointing to the other model is the name of that model with the suffix `_id` added. The `:association_foreign_key` option lets you set the name of the foreign key directly:

TIP: The `:foreign_key` and `:association_foreign_key` options are useful when setting up a many-to-many self-join. For example:

```ruby
class User < ApplicationRecord
  has_and_belongs_to_many :friends,
      class_name: "User",
      foreign_key: "this_user_id",
      association_foreign_key: "other_user_id"
end
```

##### `:autosave`

If you set the `:autosave` option to `true`, Rails will save any loaded association members and destroy members that are marked for destruction whenever you save the parent object. Setting `:autosave` to `false` is not the same as not setting the `:autosave` option. If the `:autosave` option is not present, then new associated objects will be saved, but updated associated objects will not be saved.

##### `:class_name`

If the name of the other model cannot be derived from the association name, you can use the `:class_name` option to supply the model name. For example, if a part has many assemblies, but the actual name of the model containing assemblies is `Gadget`, you'd set things up this way:

```ruby
class Parts < ApplicationRecord
  has_and_belongs_to_many :assemblies, class_name: "Gadget"
end
```

##### `:foreign_key`

By convention, Rails assumes that the column in the join table used to hold the foreign key pointing to this model is the name of this model with the suffix `_id` added. The `:foreign_key` option lets you set the name of the foreign key directly:

```ruby
class User < ApplicationRecord
  has_and_belongs_to_many :friends,
      class_name: "User",
      foreign_key: "this_user_id",
      association_foreign_key: "other_user_id"
end
```

##### `:join_table`

If the default name of the join table, based on lexical ordering, is not what you want, you can use the `:join_table` option to override the default.

##### `:validate`

If you set the `:validate` option to `false`, then associated objects will not be validated whenever you save this object. By default, this is `true`: associated objects will be validated when this object is saved.

#### Scopes for `has_and_belongs_to_many`

There may be times when you wish to customize the query used by `has_and_belongs_to_many`. Such customizations can be achieved via a scope block. For example:

```ruby
class Parts < ApplicationRecord
  has_and_belongs_to_many :assemblies, -> { where active: true }
end
```

You can use any of the standard [querying methods](active_record_querying.html) inside the scope block. The following ones are discussed below:

* `where`
* `extending`
* `group`
* `includes`
* `limit`
* `offset`
* `order`
* `readonly`
* `select`
* `distinct`

##### `where`

The `where` method lets you specify the conditions that the associated object must meet.

```ruby
class Parts < ApplicationRecord
  has_and_belongs_to_many :assemblies,
    -> { where "factory = 'Seattle'" }
end
```

You can also set conditions via a hash:

```ruby
class Parts < ApplicationRecord
  has_and_belongs_to_many :assemblies,
    -> { where factory: 'Seattle' }
end
```

If you use a hash-style `where`, then record creation via this association will be automatically scoped using the hash. In this case, using `@parts.assemblies.create` or `@parts.assemblies.build` will create orders where the `factory` column has the value "Seattle".

##### `extending`

The `extending` method specifies a named module to extend the association proxy. Association extensions are discussed in detail [later in this guide](#association-extensions).

##### `group`

The `group` method supplies an attribute name to group the result set by, using a `GROUP BY` clause in the finder SQL.

```ruby
class Parts < ApplicationRecord
  has_and_belongs_to_many :assemblies, -> { group "factory" }
end
```

##### `includes`

You can use the `includes` method to specify second-order associations that should be eager-loaded when this association is used.

##### `limit`

The `limit` method lets you restrict the total number of objects that will be fetched through an association.

```ruby
class Parts < ApplicationRecord
  has_and_belongs_to_many :assemblies,
    -> { order("created_at DESC").limit(50) }
end
```

##### `offset`

The `offset` method lets you specify the starting offset for fetching objects via an association. For example, if you set `offset(11)`, it will skip the first 11 records.

##### `order`

The `order` method dictates the order in which associated objects will be received (in the syntax used by an SQL `ORDER BY` clause).

```ruby
class Parts < ApplicationRecord
  has_and_belongs_to_many :assemblies,
    -> { order "assembly_name ASC" }
end
```

##### `readonly`

If you use the `readonly` method, then the associated objects will be read-only when retrieved via the association.

##### `select`

The `select` method lets you override the SQL `SELECT` clause that is used to retrieve data about the associated objects. By default, Rails retrieves all columns.

##### `distinct`

Use the `distinct` method to remove duplicates from the collection.

#### When are Objects Saved?

When you assign an object to a `has_and_belongs_to_many` association, that object is automatically saved (in order to update the join table). If you assign multiple objects in one statement, then they are all saved.

If any of these saves fails due to validation errors, then the assignment statement returns `false` and the assignment itself is cancelled.

If the parent object (the one declaring the `has_and_belongs_to_many` association) is unsaved (that is, `new_record?` returns `true`) then the child objects are not saved when they are added. All unsaved members of the association will automatically be saved when the parent is saved.

If you want to assign an object to a `has_and_belongs_to_many` association without saving the object, use the `collection.build` method.

### Association Callbacks

Normal callbacks hook into the life cycle of Active Record objects, allowing you to work with those objects at various points. For example, you can use a `:before_save` callback to cause something to happen just before an object is saved.

Association callbacks are similar to normal callbacks, but they are triggered by events in the life cycle of a collection. There are four available association callbacks:

* `before_add`
* `after_add`
* `before_remove`
* `after_remove`

You define association callbacks by adding options to the association declaration. For example:

```ruby
class Author < ApplicationRecord
  has_many :books, before_add: :check_credit_limit

  def check_credit_limit(book)
    ...
  end
end
```

Rails passes the object being added or removed to the callback.

You can stack callbacks on a single event by passing them as an array:

```ruby
class Author < ApplicationRecord
  has_many :books,
    before_add: [:check_credit_limit, :calculate_shipping_charges]

  def check_credit_limit(book)
    ...
  end

  def calculate_shipping_charges(book)
    ...
  end
end
```

If a `before_add` callback throws an exception, the object does not get added to the collection. Similarly, if a `before_remove` callback throws an exception, the object does not get removed from the collection.

### Association Extensions

You're not limited to the functionality that Rails automatically builds into association proxy objects. You can also extend these objects through anonymous modules, adding new finders, creators, or other methods. For example:

```ruby
class Author < ApplicationRecord
  has_many :books do
    def find_by_book_prefix(book_number)
      find_by(category_id: book_number[0..2])
    end
  end
end
```

If you have an extension that should be shared by many associations, you can use a named extension module. For example:

```ruby
module FindRecentExtension
  def find_recent
    where("created_at > ?", 5.days.ago)
  end
end

class Author < ApplicationRecord
  has_many :books, -> { extending FindRecentExtension }
end

class Supplier < ApplicationRecord
  has_many :deliveries, -> { extending FindRecentExtension }
end
```

Extensions can refer to the internals of the association proxy using these three attributes of the `proxy_association` accessor:

* `proxy_association.owner` returns the object that the association is a part of.
* `proxy_association.reflection` returns the reflection object that describes the association.
* `proxy_association.target` returns the associated object for `belongs_to` or `has_one`, or the collection of associated objects for `has_many` or `has_and_belongs_to_many`.

Single Table Inheritance
------------------------

Sometimes, you may want to share fields and behavior between different models.
Let's say we have Car, Motorcycle and Bicycle models. We will want to share
the `color` and `price` fields and some methods for all of them, but having some
specific behavior for each, and separated controllers too.

Rails makes this quite easy. First, let's generate the base Vehicle model:

```bash
$ rails generate model vehicle type:string color:string price:decimal{10.2}
```

Did you note we are adding a "type" field? Since all models will be saved in a
single database table, Rails will save in this column the name of the model that
is being saved. In our example, this can be "Car", "Motorcycle" or "Bicycle."
STI won't work without a "type" field in the table.

Next, we will generate the three models that inherit from Vehicle. For this,
we can use the `--parent=PARENT` option, which will generate a model that
inherits from the specified parent and without equivalent migration (since the
table already exists).

For example, to generate the Car model:

```bash
$ rails generate model car --parent=Vehicle
```

The generated model will look like this:

```ruby
class Car < Vehicle
end
```

This means that all behavior added to Vehicle is available for Car too, as
associations, public methods, etc.

Creating a car will save it in the `vehicles` table with "Car" as the `type` field:

```ruby
Car.create(color: 'Red', price: 10000)
```

will generate the following SQL:

```sql
INSERT INTO "vehicles" ("type", "color", "price") VALUES ('Car', 'Red', 10000)
```

Querying car records will just search for vehicles that are cars:

```ruby
Car.all
```

will run a query like:

```sql
SELECT "vehicles".* FROM "vehicles" WHERE "vehicles"."type" IN ('Car')
```
