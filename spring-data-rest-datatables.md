# Datatable Integration with REST

## Introduction ##

[Datatables](http://datatables.net/ "Datatables") is a jquery plugin I've used on a number of projects that provides a full featured table/grid control, complete with paging, filtering, and sorting.  Although it can work with an existing HTML table, it also can work with a server side data source for larger datasets.  However, integrating Datatables with a Spring MVC Controller always involved a significant amount of work.  

[Spring Data - REST](http://www.springsource.org/spring-data/rest "Spring Data -Rest")  1.0.0.M2 has just been released.  This combines the already awesome Spring Data Repositories with REST.  If you don't have any experience with Spring Data, [this](http://blog.springsource.com/2011/02/10/getting-started-with-spring-data-jpa/) is a good resource to get started.

Let's integrate the Datatables with a repository exposed via Spring Data REST.

## The Basics ##

Here's our model object:

	@Entity
	@RestResource
	public class Customer {
		
		@Id
	    @GeneratedValue(strategy = GenerationType.AUTO)
	    private Long customerId;
	
		private String name;
		private String email;
		private String favoriteColor;
	}

Getters and setters are ommitted for brevity.  Next, we'll need our repository.

	@Repository
	public interface CustomerRepository extends PagingAndSortingRepository<Customer, Long> {
		 public List<Customer> findByNameLike(@Param("name") String name);
	}

Notice the support for the findByNameLike queries.  We'll be using this later in our datatable.

And then in our applicationContext.xml, tell Spring Data where to find our repository interfaces:

	<jpa:repositories base-package="com.sdg.blog.repos" />

	
And that's all that's needed for our repository.  Once we tell Spring Data where our repository interfaces are defined, it will allow us to inject the repositories into any of our other Spring managed beans.  Repositories will provide CRUD operations, `findAll`, `findOne`, `exists`, and many more methods, through some sort of black magic I don't pretend to understand.

## REST Support ##

Now we need to enable REST support.  First, let's include the dependency for Spring Data -REST in the pom.xml:

	<dependency>
		<groupId>org.springframework.data</groupId>
		<artifactId>spring-data-rest-webmvc</artifactId>
		<version>1.0.0.RC2</version>
	</dependency>

And for this example, we'll have all of the REST requests go thru a separate servlet.  Here's the web.xml with the relevant bytes:

	  <servlet>
	    <servlet-name>exporter</servlet-name>
	    <servlet-class>org.springframework.data.rest.webmvc.RepositoryRestExporterServlet</servlet-class>
	    <load-on-startup>1</load-on-startup>
	  </servlet>
	  <servlet-mapping>
	    <servlet-name>exporter</servlet-name>
	    <url-pattern>/rest/*</url-pattern>
	  </servlet-mapping>


Once this is done, and the web application is started, we can start pushing in data like this:

`curl http://localhost:8080/sdrdemo/rest/customer -d "{\"name\":\"John Smith\"}" -H "Content-Type: application/json"`

And you can retrieve data using

`curl http://localhost:8080/sdrdemo/rest/customer`

Remember the `findByNameLike` method we added to our Customer interface?  That is exposed as well, and can be called using

`curl http://localhost:8080/sdrdemo/rest/customer/search/findByNameLike?name=%25J%25
`
## Datatable Integration ##

Now it's time for the fun stuff.  We'll set up a very simple datatable.  Our HTML looks like this:

	<table id="customers">
		<thead>
			<tr>
				<th>Name</th>
		    	<th>Email</th>
			</tr>
		</thead>
		<tbody/>
	</table>

And finally, our javascript to initialize the datatable:  This will be a very simple example, which will pull the entire list of customers from the database.  All sorting, paging, and filtering is handled on the client's browser.

		$('#customerTable').dataTable({
			"sAjaxSource" : '${baseUrl}rest/customer?limit=1000',
			"sAjaxDataProp" : 'results',
			"aoColumns" : [ {
				mDataProp : 'name'
			}, {
				mDataProp : 'email'
			} ]
		});

This gives us a table that looks like this.


![Datatable Example](https://dl.dropbox.com/u/336272/datatable_ex.png)


It's not bad for small datasets, but for larger ones, we'll want to do the heavy lifting on the server.  In order to so, we set the bServerSide parameter to true.  This will tell Datatable to perform an AJAX request for each new page, sort command, or filter.  The problem is, Datatable is going to be sending us hungarian notation style parameters  parameters like `iDisplayLength`, `iDisplayStart`, `mDataProp_0`, `iSortCol_0`, `sSortDir_0`

Our REST service expects `limit`, `page`, `sort`.  Fortunately, Datatable provides a hook that allows us to override the server call. We'll start by creating a function that translates our Datatable parameters to ones the REST service understands:

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

That being done, we override the default Datatable server call with our own:
	
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


#Conclusion#

Full source code can be found at [github](https://github.com/gcase/spring-data-rest-datatable-example).

I've shown how using the Spring Data REST coupled with the Databable plugin can provide a highly functional table control with a relatively small amount of code.   The javascript used to convert from the Datatable parameters to the REST paging syntax can easily be refactored and shared among many tables.   From here, it'd be trivial to wire in basic CRUD functionality using the exposed REST service.

