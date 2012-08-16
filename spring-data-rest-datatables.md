# Datatable Integration with REST

## Introduction ##

[Datatables](http://datatables.net/ "Datatables") is a jquery plugin I've used on a number of projects that provides a full featured table/grid control, complete with paging, filtering, and sorting.  Although it can work with an existing HTML table, it also can work with a server side data source for larger datasets.  However, integrating Datatables with a Spring MVC Controller always involved a significant amount of work.  

[Spring Data - REST](http://www.springsource.org/spring-data/rest "Spring Data -Rest")  1.0.0.M2 has just been released.  This combines the already awesome Spring Data Repositories with REST.  If you don't have any experience with Spring Data, [this](http://blog.springsource.com/2011/02/10/getting-started-with-spring-data-jpa/) is a good resource to get started.

Let's integrate the Datatables with a repository exposed via Spring Data REST.  In order to do so, we'll create a simple Spring MVC project.  Maven will be used for dependency managements and building.  This article assumes the reader has basic understanding of the Spring Framework and REST.

## The Basics ##

Here's our model object, [Customer.java](https://github.com/gcase/spring-data-rest-datatable-example/blob/master/src/main/java/com/sdg/sdrdemo/models/Customer.java):

```java
@Entity
@RestResource
public class Customer {
	
	@Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Long customerId;

	private String name;
	private String email;
	private String favoriteColor;

	//getters and setters omitted
}
```
Next, we'll need to define a [CustomerRepository](https://github.com/gcase/spring-data-rest-datatable-example/blob/master/src/main/java/com/sdg/sdrdemo/repos/CustomerRepository.java) interface. The CustomerRepository extends [PagingAndSortingRepository](http://static.springsource.org/spring-data/data-commons/docs/1.3.2.RELEASE/api/org/springframework/data/repository/PagingAndSortingRepository.html), which is what defines the paging, sorting, and CRUD methods.

```java
@Repository
public interface CustomerRepository extends PagingAndSortingRepository<Customer, Long> {
	 public List<Customer> findByNameLike(@Param("name") String name);
}
```

Notice the support for the findByNameLike queries.  We'll be using this later in our datatable.

And then in our [applicationContext.xml](https://github.com/gcase/spring-data-rest-datatable-example/blob/master/src/main/resources/META-INF/spring/applicationContext.xml), tell Spring Data where to find our repository interfaces:

```xml
<jpa:repositories base-package="com.sdg.sdrdemo.repos" />
```
	
And that's all that's needed for our repository.  No implementing class is needed! Once we tell Spring Data where our repository interfaces are defined, it will allow us to inject the repositories into any of our other Spring managed beans.  Repositories will provide CRUD operations, `findAll`, `findOne`, `exists`, and many more methods, through some sort of black magic I don't pretend to understand.

## REST Support ##

The Spring Data REST library works together with the core Spring Data to expose the Repositories.  It includes a servlet that will match incoming requests to a repository.  For example, any request that comes in with the path `sdrdemo/request/customer` it will attempt to fulfill by delegating requests to the `CustomerRepository`. An **HTTP GET** `sdrdemo/request/customer` will return an array of Customers, **GET** `sdrdemo/request/customer/42` will return a Customer with customerId 42,  **DELETE** `sdrdemo/request/customer/42` will delete the specified Customer, etc.   All of this is done with very little configuration. The `@RestResource` annoation can be used to customize url mappsings and hide specific fields, methods.  

A full list of features and documentation found here: http://www.springsource.org/spring-data/rest

So how does this work in practice?  First, let's include the dependency for Spring Data - REST in the [pom.xml](https://github.com/gcase/spring-data-rest-datatable-example/blob/master/pom.xml):

```xml
<dependency>
	<groupId>org.springframework.data</groupId>
	<artifactId>spring-data-rest-webmvc</artifactId>
	<version>1.0.0.RC2</version>
</dependency>
```



And for this example, we'll have all of the REST requests go thru a separate servlet.  Here's the relevant bytes from the [web.xml](https://github.com/gcase/spring-data-rest-datatable-example/blob/master/src/main/webapp/WEB-INF/web.xml):

```xml
<servlet>
	<servlet-name>exporter</servlet-name>
	<servlet-class>org.springframework.data.rest.webmvc.RepositoryRestExporterServlet</servlet-class>
	<load-on-startup>1</load-on-startup>
</servlet>
<servlet-mapping>
	<servlet-name>exporter</servlet-name>
	<url-pattern>/rest/*</url-pattern>
</servlet-mapping>
```

When the `RepositoryRestExporterServlet` starts up, it will look for a spring config file under META-INF/spring-data-rest ending with -export.xml.  [Here](https://github.com/gcase/spring-data-rest-datatable-example/blob/master/src/main/resources/META-INF/spring-data-rest/repositories-export.xml) is a very simple one I used for this project.  It simply imports the main applicationContext.xml, which we've already covered above.

Once this is done, and the web application is started, we can start pushing in data like this:

`curl http://localhost:8080/sdrdemo/rest/customer -d "{\"name\":\"John Smith\"}" -H "Content-Type: application/json"`

And you can retrieve data using

`curl http://localhost:8080/sdrdemo/rest/customer`

Remember the `findByNameLike` method we added to our Customer interface?  That is exposed as well, and can be called using

`curl http://localhost:8080/sdrdemo/rest/customer/search/findByNameLike?name=%25John%25`

(**%25** is the `%` wildcard character url-encoded)

## Datatable Integration ##

Now it's time for the fun stuff.  We'll set up a very simple datatable.  Our HTML looks like this:

```html
<table id="customers">
	<thead>
		<tr>
			<th>Name</th>
	    	<th>Email</th>
		</tr>
	</thead>
	<tbody/>
</table>
```

And finally, our javascript to initialize the datatable:  This will be a very simple example, which will pull the entire list of customers from the database.  All sorting, paging, and filtering is handled on the client's browser.

```javascript
$('#customerTable').dataTable({
	"sAjaxSource" : '${baseUrl}rest/customer?limit=1000',
	"sAjaxDataProp" : 'results',
	"aoColumns" : [ {
		mDataProp : 'name'
	}, {
		mDataProp : 'email'
	} ]
});
```

A quick explanation of the options we are using:  `sAjaxSource` is the URL that DataTable will make a rquest to.  For this simple example, we hard-coded a limit of 1000.  Otherwise, our service will return only the first 20 results. 

Next, `sAjaxDataProp` tells DataTable that to use the data under the results attribute for our Customer array.

Finally, the 'aoColomns' property stores our column configuration.  This is a very simple table, we just want to map` Customer.name` to the first column, and `Customer.email` to the second column.  

For reference, here is a snippet of the JSON response we'll be getting back from the REST service:

```javascript	
	{
	  "results" : [ {
	    "email" : "mcbrayer.norris@example.com",
	    "name" : "Norris Mcbrayer",
	    "_links" : [ {
	      "rel" : "self",
	      "href" : "http://localhost:8080/sdrdemo/rest/customer/1"
	    } ]
	  }, {
	    "email" : "kubota.al@example.com",
	    "name" : "Al Kubota",
	    "_links" : [ {
	      "rel" : "self",
	      "href" : "http://localhost:8080/sdrdemo/rest/customer/2"
	    } ]
	  },
	// more results here
    ]
	}
```
You can also see here how the REST response provides hrefs for each Customer.  A more advanced example could use these links to provide detailed forms, or Update / Delete functionality.

Anyways, once we have that in place, here is what our generated table looks like:

![Datatable Example](https://dl.dropbox.com/u/336272/datatable_ex.png)


It's not bad for small datasets, but for larger ones, we'll want to do the heavy lifting on the server.  In order to so, we set the `bServerSide` parameter to true.  This will tell Datatable to perform an AJAX request for each new page, sort command, or filter.  The problem is, Datatable is going to be sending us hungarian notation style parameters  parameters like `iDisplayLength`, `iDisplayStart`, `mDataProp_0`, `iSortCol_0`, `sSortDir_0`

Our REST service expects `limit`, `page`, `sort`.  Fortunately, Datatable provides a hook that allows us to override the server call. We'll start by creating a function that translates our Datatable parameters to ones the REST service understands:

```javascript
var datatable2Rest = function(sSource, aoData, fnCallback) {
	
	//extract name/value pairs into a simpler map for use later
	var paramMap = {};
	for ( var i = 0; i < aoData.length; i++) {
		paramMap[aoData[i].name] = aoData[i].value;
	}

	//page calculations
	var pageSize = paramMap.iDisplayLength;
	var start = paramMap.iDisplayStart;
	var pageNum = (start == 0) ? 1 : (start / pageSize) + 1; // pageNum is 1 based
	
	// extract sort information
	var sortCol = paramMap.iSortCol_0;
	var sortDir = paramMap.sSortDir_0;
	var sortName = paramMap['mDataProp_' + sortCol];

	//create new json structure for parameters for REST request
	var restParams = new Array();
	restParams.push({"name" : "limit", "value" : pageSize});
	restParams.push({"name" : "page", "value" : pageNum });
	restParams.push({"name" : "sort", "value" : sortName });
	restParams.push({"name" : sortName + ".dir", "value" : sortDir });

	//if we are searching by name, override the url and add the name parameter
	var url = sSource;
	if (paramMap.sSearch != '') {
		url = "${baseUrl}rest/customer/search/findByNameLike";
		var nameParam =  '%' + paramMap.sSearch + '%'; // add wildcards
		restParams.push({ "name" : "name", "value" : nameParam});
	}
	
	//finally, make the request
	$.ajax({
		"dataType" : 'json',
		"type" : "GET",
		"url" : url,
		"data" : restParams,
		"success" : function(data) {
			data.iTotalRecords = data.totalCount;
			data.iTotalDisplayRecords = data.totalCount;

			fnCallback(data);
		}
	});
};
```

That being done, our new DataTable setup looks like this.  `bServerSide` is set to true, and we've set `fnServerData` with the `datatable2Rest` function that was just defined.

```javascript
$('#customerTable').dataTable({
	"sAjaxSource" : '${baseUrl}rest/customer',
	"sAjaxDataProp" : 'results',
	"aoColumns" : [ {
		mDataProp : 'name'
	}, {
		mDataProp : 'email'
	} ],
	"bServerSide" : true,
	"fnServerData" : datatable2Rest
});
```


#Conclusion#

Full source code can be found at [github](https://github.com/gcase/spring-data-rest-datatable-example).

I've shown how using the Spring Data REST coupled with the Databable plugin can provide a highly functional table control with a relatively small amount of code.   The javascript used to convert from the Datatable parameters to the REST paging syntax can easily be refactored and shared among many tables.   From here, it'd be trivial to wire in basic CRUD functionality using the exposed REST service.

