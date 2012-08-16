# Spring Data - REST integration with Datatables #

This project demonstrates the basic functionality of integrating Spring Data - REST with the Datatable jquery plugin.  The original blog post can be found here [Insert SDG Blog Link Here].


## Getting Started ##

This project required Maven.  To start the application, type

`mvn jetty:run`

The application will start, persisting data to an in memory database.  To populate the Customers table, you can use curl:

`curl http://localhost:8080/sdgBlog/rest/customer -d "{\"name\":\"John Smith\"}" -H "Content-Type: application/json"`

Also, `load_names.rb` file is provided, that will load the database with the contents of `names.txt`

To see the datable in action, point your browser to [http://localhost:8080/sdr_demo](http://localhost:8080/sdrdemo)


  