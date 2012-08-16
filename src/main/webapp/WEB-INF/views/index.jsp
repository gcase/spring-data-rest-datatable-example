<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib uri="http://www.springframework.org/tags" prefix="spring" %>
<%@ page session="false" %>
<spring:url value="/" var="baseUrl" />

<!doctype html>
<head>
  <title>Customers</title>
   <link rel="stylesheet" href="http://ajax.aspnetcdn.com/ajax/jquery.dataTables/1.9.2/css/jquery.dataTables.css">
</head>

  <div role="main">

	<h1>Customers</h1>
	<table id="customerTable">
		<thead>
			<tr>
				<th>Name</th>
				<th>Email</th>
			</tr>
		</thead>
		<tbody/>
	</table>	

  </div>

  <script src="//ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.min.js"></script>
  <script src="//ajax.aspnetcdn.com/ajax/jquery.dataTables/1.9.2/jquery.dataTables.min.js"></script>

	<script type="text/javascript">
	$(function() {

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
			restParams.push({ "name" : "sort", "value" : sortName });
			restParams.push({ "name" : sortName + ".dir", "value" : sortDir });
		
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
					

	});
	</script>

</body>

</html>