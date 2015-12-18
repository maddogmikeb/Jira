<html>
<head>
    <title>Jira Templater</title>
    <script src="http://code.jquery.com/jquery-2.1.3.min.js"></script>
    <style>
        * {
            font-size: 12px;
        }

        body {
            background-color: white;
            color: black;
            font-family: 'Courier New', Courier, 'Lucida Sans Typewriter', 'Lucida Typewriter', monospace;
        }

        .WallBoard {
            background-color: black;
            color: white;
        }

        #Filter {
            font-size: 22pt;
        }
    </style>
</head>
<body>    
    <section id="Templater">
			<textarea id="jsonTemplate" rows="45" cols="80">Loading...</textarea>
    </section>
	
	</br>
	<input type="button" id="go" value="Create" />
	
	<span id="Loading">
		Loading...
	</span>

    <div id="console"></div>

    <script>
        var codebase = "http://vaws19tfss3001/Jira_Extensions/";
		var proxy = codebase + "JSONToJira.aspx";
		
        var jiraBase = "http://jira.racqgroup.local:12001/rest/api/latest/";
        var jiraIssue = jiraBase + "issue/";
		var jiraEpics = jiraBase + "epics/{epic-key}/add";
		var jiraLink = jiraBase + "issueLink";
		
		// how to find all fields 
		// http://jira.racqgroup.local:12001/rest/api/latest/issue/createmeta?projectKeys=ICC&issuetypeName=Story&expand=projects.issuetypes.fields
		
		var queries = {};
		var issueTemplate, updateTemplate, linkTemplate;
   
        $(document).ready(function () {

            if (document.referrer.indexOf("/plugins/servlet/gadgets/") > 0) {
                $("body").addClass("Wallboard");
            }
         
            $.each(document.location.search.substr(1).split('&'), function (c, q) {
                var i = q.split('=');
                queries[i[0].toString()] = i[1].toString();
            });
			
			LoadTemplate(queries["template"], function(data) { $("#jsonTemplate").html(data); } );
			LoadSystemTemplates();
			
			$("#go").click(function() 
			{
				$("#console").html("");
				$("#go, #jsonTemplate").attr("disabled", true);
				
				var obj = $.parseJSON( $("#jsonTemplate").val() );
				CreateStory( obj, function(story) {
					CreateTasks(obj, story, function(task) {
						CreateSubtasks(obj, story, task, function(subtask) {
							$("#go, #jsonTemplate").removeAttr("disabled");
						});						
					});
				});
			});
			
			$("#Loading").text('Working...');
        });
		
		function LoadSystemTemplates()
		{
			LoadTemplate("_createIssue", function(data) { issueTemplate = $.parseJSON( data ); } );
			LoadTemplate("_updateIssue", function(data) { updateTemplate = $.parseJSON( data ); } );
			LoadTemplate("_createLink", function(data) { linkTemplate = $.parseJSON( data ); } );
		}
		
		function LoadTemplate(name, callback) 
		{
			$.ajax({
				url : name + ".json",
				dataType: "text",
				success : function (data) {
					callback(data);					
				}
			});
		}
		
		function CreateStory(obj, callback) 
		{		
			if (obj.story.key != null) {
				$("#console").append("Story already exists " + obj.story.key + "</br>");
				callback(obj.story);
				return;
			}
		
			var story = (JSON.parse(JSON.stringify(issueTemplate)));
			story.fields.project.key = obj.project;
			story.fields.summary = obj.story.summary;
			story.fields.description = obj.story.description;
			story.fields.issuetype.name = "Story";
			story.fields.customfield_10073 = obj.story.epiclinkid;
			
			$.ajax({
				type: "POST",
				url: proxy + "?url=" + encodeURIComponent(jiraIssue),
				dataType: "json",
				data: JSON.stringify( story ),
			}).done(function ( newStory ) {				
				var newStoryUpdate = (JSON.parse(JSON.stringify(updateTemplate)));
				newStoryUpdate.update.fixVersions[0].set[0].name = obj.story.fixversion;				
				
				for (var i = 0; i < obj.story.labels.length; i++) {
					newStoryUpdate.update.labels.push ( { "add" : obj.story.labels[i].replace("{STORY_KEY}", newStory.key) } );
				}
				
				$.ajax({
					type: "PUT",
					url: proxy + "?url=" + encodeURIComponent(jiraIssue + newStory.key),
					dataType: "json",
					data: JSON.stringify( newStoryUpdate )
				}).done(function (data) 
				{				
					$("#console").append("Created new story <a href='" + newStory.self + "'>" + newStory.key + "</a></br>");
					callback(newStory);
				}).fail(function(x, s){
					if (x.statusText == "OK") 
					{
						$("#console").append("Created new story <a href='" + newStory.self + "'>" + newStory.key + "</a></br>");
						callback(newStory);
					}
				});
			})
		}
		
		function CreateTasks(obj, story, callback) 
		{
			$.each(obj.story.tasks.issues, function (index, taskObj) 
			{
				var task = (JSON.parse(JSON.stringify(issueTemplate)));
				task.fields.project.key = obj.project;
				task.fields.summary = taskObj.summary;
				task.fields.description = taskObj.description;
				task.fields.issuetype.name = "Task";
				task.fields.customfield_10073 = obj.story.epiclinkid;
				
				$.ajax({
					type: "POST",
					url: proxy + "?url=" + encodeURIComponent(jiraIssue),
					dataType: "json",
					data: JSON.stringify( task ),
				}).done(function ( newTask ) {				
					var newTaskUpdate = (JSON.parse(JSON.stringify(updateTemplate)));
					newTaskUpdate.update.fixVersions[0].set[0].name = obj.story.fixversion;
					
					for (var i = 0; i < obj.story.labels.length; i++) {
						newTaskUpdate.update.labels.push ( { "add" : obj.story.labels[i].replace("{STORY_KEY}", story.key) } );
					}
					
					$.ajax({
						type: "PUT",
						url: proxy + "?url=" + encodeURIComponent(jiraIssue + newTask.key),
						dataType: "json",
						data: JSON.stringify( newTaskUpdate )
					}).fail(function (x, s) 
					{						
						if (x.statusText != "OK") 
						{
							return;
						}
						var link = (JSON.parse(JSON.stringify(linkTemplate)));				
						link.inwardIssue.key = story.key;
						link.outwardIssue.key = newTask.key;
					
						$.ajax({
							type: "POST",
							url: proxy + "?url=" + encodeURIComponent(jiraLink),
							dataType: "json",
							data: JSON.stringify( link )
						}).done(function (data) 
						{				
							$("#console").append("Created new task <a href='" + newTask.self + "'>" + newTask.key + "</a></br>");
							callback(newTask);
						}).fail(function(x, s){
							if (x.statusText == "OK") 
							{
								newTask.index = index;
								
								$("#console").append("Created new task <a href='" + newTask.self + "'>" + newTask.key + "</a></br>");
								callback(newTask);							
							}
						});
					});
				});
			});
		}
		
		function CreateSubtasks(obj, story, task, callback) 
		{
			$.each(obj.story.tasks.issues[task.index].subtasks, function (i, subtaskObj) 
			{
				var subtask = (JSON.parse(JSON.stringify(issueTemplate)));
				subtask.fields.project.key = obj.project;
				subtask.fields.summary = subtaskObj.summary;
				subtask.fields.description = subtaskObj.description;
				subtask.fields.issuetype.name = "Sub-Task";
				subtask.fields.customfield_10073 = null;
				subtask.fields.parent = {};
				subtask.fields.parent.id = task.key;
				
				$.ajax({
					type: "POST",
					url: proxy + "?url=" + encodeURIComponent(jiraIssue),
					dataType: "json",
					data: JSON.stringify( subtask ),
				}).done(function ( newSubTask ) {
					var newSubTaskUpdate = (JSON.parse(JSON.stringify(updateTemplate)));
					newSubTaskUpdate.update.fixVersions[0].set[0].name = obj.story.fixversion;
					
					for (var i = 0; i < obj.story.labels.length; i++) {
						newSubTaskUpdate.update.labels.push ( { "add" : obj.story.labels[i].replace("{STORY_KEY}", story.key) } );
					}
					
					$.ajax({
						type: "PUT",
						url: proxy + "?url=" + encodeURIComponent(jiraIssue + newSubTask.key),
						dataType: "json",
						data: JSON.stringify( newSubTaskUpdate )
					}).done(function (data)
					{
						$("#console").append("Created new subtask <a href='" + newSubTask.self + "'>" + newSubTask.key + "</a></br>");
						callback(newSubTask);
					}).fail(function(x, s){
						if (x.statusText == "OK") 
						{
							$("#console").append("Created new subtask <a href='" + newSubTask.self + "'>" + newSubTask.key + "</a></br>");				
						}
						callback(newSubTask);
					});
				});
			});
		}

        $(document).ajaxStart(function () {
            $("#Loading").show();
        });

        $(document).ajaxStop(function () {
            if (0 === $.active) {
                $("#Loading").hide();
            }
        }); 

    </script>
</body>
</html>
