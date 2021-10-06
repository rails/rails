

Bienvenido a Rails
¿Qué es Rails?
Rails es un marco de aplicación web que incluye todo lo necesario para crear aplicaciones web respaldadas por bases de datos de acuerdo con el patrón Modelo-Vista-Controlador (MVC) .

Comprender el patrón MVC es clave para comprender Rails. MVC divide su aplicación en tres capas: modelo, vista y controlador, cada una con una responsabilidad específica.

Capa de modelo
La capa Modelo representa el modelo de dominio (como Cuenta, Producto, Persona, Publicación, etc.) y encapsula la lógica empresarial específica de su aplicación. En Rails, las clases de modelos respaldadas por bases de datos se derivan de ActiveRecord::Base. Active Record le permite presentar los datos de las filas de la base de datos como objetos y embellecer estos objetos de datos con métodos de lógica empresarial. Aunque la mayoría de los modelos de Rails están respaldados por una base de datos, los modelos también pueden ser clases de Ruby ordinarias o clases de Ruby que implementan un conjunto de interfaces proporcionadas por el módulo Active Model .

Capa de controlador
La capa de controlador es responsable de manejar las solicitudes HTTP entrantes y proporcionar una respuesta adecuada. Por lo general, esto significa devolver HTML, pero los controladores Rails también pueden generar XML, JSON, PDF, vistas específicas para dispositivos móviles y más. Los controladores cargan y manipulan modelos y renderizan plantillas de vista para generar la respuesta HTTP adecuada. En Rails, las solicitudes entrantes son enrutadas por Action Dispatch a un controlador apropiado, y las clases de controlador se derivan de ActionController::Base. Action Dispatch y Action Controller están agrupados en Action Pack .

Ver capa
La capa Ver está compuesta por "plantillas" que son responsables de proporcionar representaciones adecuadas de los recursos de su aplicación. Las plantillas pueden venir en una variedad de formatos, pero la mayoría de las plantillas de vista son HTML con código Ruby incrustado (archivos ERB). Las vistas se representan normalmente para generar una respuesta de controlador o para generar el cuerpo de un correo electrónico. En Rails, la generación de vistas es manejada por Action View .

Marcos y bibliotecas
Active Record , Active Model , Action Pack y Action View se pueden utilizar independientemente fuera de Rails. Además de eso, Rails también viene con Action Mailer , una biblioteca para generar y enviar correos electrónicos; Action Mailbox , una biblioteca para recibir correos electrónicos dentro de una aplicación Rails; Active Job , un marco para declarar trabajos y hacer que se ejecuten en una variedad de backends de cola; Action Cable , un marco para integrar WebSockets con una aplicación Rails; Active Storage , una biblioteca para adjuntar archivos locales y en la nube a aplicaciones Rails; Action Text , una biblioteca para manejar contenido de texto enriquecido; yActive Support , una colección de clases de utilidad y extensiones de biblioteca estándar que son útiles para Rails y que también se pueden usar de forma independiente fuera de Rails.

Empezando
Instale Rails en el símbolo del sistema si aún no lo ha hecho:

 $ gem install rails
En el símbolo del sistema, cree una nueva aplicación Rails:

 $ rails new myapp
donde "myapp" es el nombre de la aplicación.

Cambie de directorio myappe inicie el servidor web:

 $ cd myapp
 $ bin/rails server
Ejecutar con --helpo -hpara opciones.

Ve a http://localhost:3000y verás: "¡Yay! ¡Estás sobre rieles!"

Siga las pautas para comenzar a desarrollar su aplicación. Puede encontrar útiles los siguientes recursos:

Introducción a Rails
Guías de Ruby on Rails
La documentación de la API
Contribuyendo
¡Le animamos a contribuir a Ruby on Rails! Consulte la guía Contribución a Ruby on Rails para obtener pautas sobre cómo proceder. ¡Únete a nosotros!

¿Está intentando informar de una posible vulnerabilidad de seguridad en Rails? Consulte nuestra política de seguridad para conocer las pautas sobre cómo proceder.

Se espera que todas las personas que interactúen en Rails y las bases de código de sus subproyectos, rastreadores de problemas, salas de chat y listas de correo sigan el código de conducta de Rails .

Licencia
Ruby on Rails se lanza bajo la licencia MIT .
