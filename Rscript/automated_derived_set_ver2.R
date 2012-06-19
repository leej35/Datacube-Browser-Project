


getderivedset <- function(state_uri,behavior_uri,law_uri){
		
	print (c(state_uri,behavior_uri,law_uri))
	#1 : Query for dataframe x
	
	measuresQuery  <- paste0("
	PREFIX ro:      <http://www.obofoundry.org/ro/ro.owl#>
	PREFIX dcterms: <http://purl.org/dc/terms/>
	PREFIX datacube: <http://logd.tw.rpi.edu/source/data-gov/datacube/>
	PREFIX qb: <http://purl.org/linked-data/cube#>
	PREFIX rdfs: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
	PREFIX rdfs2: <http://www.w3.org/2000/01/rdf-schema#>
	
	select DISTINCT ?measureLabel_behavior max(?value_behavior) as ?value_behavior ?measureLabel_law max(?value_law) as ?value_law ?stateLabel ?year  where {
	    graph <http://logd.tw.rpi.edu/source/impacteen-org/dataset/tobacco-control-policy-and-prevalence/version/2012-Jan-16> {
	        ?ob_behavior qb:measureType ",behavior_uri,";
	          a datacube:SingularValue;
	          <http://www.w3.org/ns/prov-o/startedAt> ?year;
	          <http://www.w3.org/ns/prov-o/location> ?states;
	          <http://purl.org/linked-data/cube#measureType> ?measure_behavior;
	          rdfs:value ?value_behavior.
	          ?states rdfs2:label ?stateLabel.
	          ?measure_behavior rdfs2:label ?measureLabel_behavior.
	
	        ?ob_law qb:measureType ",law_uri,";
	          a datacube:SingularValue;
	          <http://www.w3.org/ns/prov-o/startedAt> ?year;
	          <http://www.w3.org/ns/prov-o/location> ?states;
	          <http://purl.org/linked-data/cube#measureType> ?measure_law;
	          rdfs:value ?value_law.
	          ?measure_law rdfs2:label ?measureLabel_law.	     
	
	filter ( ?states = ",state_uri,")
	    }
	} GROUP BY ?measureLabel_behavior ?measureLabel_law ?stateLabel ?year
	ORDER BY ?measureLabel_behavior ?measureLabel_law ?stateLabel ?year
	");
	#cat(measuresQuery) 
	endpoint = "http://logd.tw.rpi.edu/sparql.php";
	dataX = SPARQL(url=endpoint,query=measuresQuery)$results;
	
	#Exception: number of tuples is less than 4
	if(length(colnames(dataX)) < 5 || length(rownames(dataX)) == 1){
		print(dataX)
		stop("incorrect result shape")

	}

	
	
	# Sort by year
	dataX <- dataX[with(dataX,order(dataX$year)),];
	
	dataX$year = as.numeric(as.character(dataX$year));
	dataX$value_behavior = as.numeric(as.character(dataX$value_behavior));
	
	#print(dataX)
		
		
	
	#2 : Create Derived Set  
	
	derivedset <- function(x,lawColumn,behavColumn,yearColumn){
		
		# mark point of change in law_set
		j = 1;
		mark = 0;
	
		for(i in 1:length(rownames(x))){
			
			
			#Exception: If first law_measure value is not zero, ignore the set.
			if(x[1,lawColumn] != 0){
				stop("first law_measure value is not zero")
			}
			
			
			if(x[i,lawColumn] != 0){
				mark =i;
				break;
			}
		}
		result = NULL;
		if(mark!=0){
			result$before = x[1:mark-1,];
			result$after = x[mark:length(rownames(x)),];	
			result$mark = x$year[mark];
			result$beforeLaw = x$value_law[mark-1];
			result$afterLaw = x$value_law[mark];
		}
		else{
			#Exception: When there is no derivedset (no chagnes in law measure)
			stop("No changes in law")
		}
		
		#Exception: When 'year of after' is shorter than two
		if(length(rownames(result$after)) < 2){
			stop("only one year available after law change")
		}
		#Exception: When 'year of before' is shorter than two
		if(length(rownames(result$before)) < 2){
			stop("only one year available before law change")
		}
		
		
		return(result);
	}
	
	
	# Run function derivedset to create derived set
	derived <- derivedset(dataX,"value_law","value_behavior","year");
	
		
	
	#3 : Calcualte Coefficient
	
	# Convert years as numeric
	#derived$before$year <- as.numeric(as.character(derived$before$year));
	#derived$after$year <- as.numeric(as.character(derived$after$year));
	
	#print (derived);
	# Calculate coefficients
	coeff = NULL;
	
	coefficient <- lm(value_behavior ~ year, data=derived$before);
	coeff$before <- coefficient$coefficients[2]
	
	#print ("after")
	coefficient <- lm(value_behavior ~ year, data=derived$after);
	coeff$after <- coefficient$coefficients[2]
	
	
	#make years into one string
	yearString = NULL;
	years = NULL;
	year = NULL;
	years = c(as.numeric(as.character(dataX$year)));
	for(year in years){
		yearString = paste(yearString,year,"/",sep="");
	}
	
	
	#4 : Return result
	result = data.frame(state_measure_uri=c(state_uri),
				law_measure_uri = c(law_uri),
				behavior_measure_uri = c(behavior_uri),
				before = c(as.numeric(coeff$before)),
				after = c(as.numeric(coeff$after)),
				change = c(as.numeric(coeff$after)-as.numeric(coeff$before)),
				yearchange = c(derived$mark),
				startedAt = c(min(dataX$year)),
				endedAt = c(max(dataX$year)),
				beforeLaw = c(derived$beforeLaw),
				afterLaw = c(derived$afterLaw),
				yearString 
				)
	return(result)
	
}



getMeasuresIn <- function(category) {
     #list_law_measure
	measuresQuery  <- paste0("
	PREFIX ro:      <http://www.obofoundry.org/ro/ro.owl#>
	PREFIX dcterms: <http://purl.org/dc/terms/>
	PREFIX datacube: <http://logd.tw.rpi.edu/source/data-gov/datacube/>
	PREFIX qb: <http://purl.org/linked-data/cube#>
	
	select DISTINCT ?measure where {
	    graph <http://logd.tw.rpi.edu/source/impacteen-org/dataset/tobacco-control-policy-and-prevalence/version/2012-Jan-16> {
	        ?measure ro:part_of <",category,"> .
	    }
	}");
	endpoint = "http://logd.tw.rpi.edu/sparql.php";
	return (as.character(SPARQL(url=endpoint,query=measuresQuery)$results));
	
}

#############################################################################


#auto_derived_set <- function(){

	#list_states 
	measuresQuery  = "
	PREFIX ro:      <http://www.obofoundry.org/ro/ro.owl#> 
	PREFIX dcterms: <http://purl.org/dc/terms/> 
	PREFIX datacube: <http://logd.tw.rpi.edu/source/data-gov/datacube/> 
	PREFIX qb: <http://purl.org/linked-data/cube#> 
	select DISTINCT ?o where { 
	    graph <http://logd.tw.rpi.edu/source/impacteen-org/dataset/tobacco-control-policy-and-prevalence/version/2012-Jan-16> {
	[] <http://www.w3.org/ns/prov-o/location>	?o    }
	}";
	endpoint = "http://logd.tw.rpi.edu/sparql.php";
	states = SPARQL(url=endpoint,query=measuresQuery)$results;
	states <-as.character(states);
	print(states)
	
	
	laws = getMeasuresIn("http://health.tw.rpi.edu/source/impacteen-org/dataset/tobacco-control-policy-and-prevalence/category/Smoke-Free_Air_Preemption");
	print("List of Law Measures");
	print(laws);
	
#	behaviors = c("http://health.tw.rpi.edu/source/impacteen-org/dataset/tobacco-control-policy-and-prevalence/measure/NSDUH_Past_month_cigarette_use_Overall",
				#"http://health.tw.rpi.edu/source/impacteen-org/dataset/tobacco-control-policy-and-prevalence/measure/NSDUH_Past_month_tobacco_use_Overall",
				#"http://health.tw.rpi.edu/source/impacteen-org/dataset/tobacco-control-policy-and-prevalence/measure/YTS_Current_cigarette_use_High_school_students",
				#"http://health.tw.rpi.edu/source/impacteen-org/dataset/tobacco-control-policy-and-prevalence/measure/Prevalence_of_Current_Cigarette_Smoking_-_ages_30_years",
				#"http://health.tw.rpi.edu/source/impacteen-org/dataset/tobacco-control-policy-and-prevalence/measure/Prevalence_of_Current_Cigarette_Smoking_-_ages_18-29_years",
				#"http://health.tw.rpi.edu/source/impacteen-org/dataset/tobacco-control-policy-and-prevalence/measure/Percentage_of_ever_smokers_who_have_quit-_ages_18_yrs",
				#"http://health.tw.rpi.edu/source/impacteen-org/dataset/tobacco-control-policy-and-prevalence/measure/NSDUH_Past_month_tobacco_use_Ages_12-17_years")
				
	behaviors = getMeasuresIn("http://health.tw.rpi.edu/source/impacteen-org/dataset/tobacco-control-policy-and-prevalence/category/Youth_Risk_Behavior_Surveillance_System");
	print("List of Behavior Measures");
	print (behaviors);
	
	errors = data.frame(state=c(),behavior=c(),law=c(),error=c());
	result = data.frame(cbind(state_measure_uri=c(),
				law_measure_uri = c(),
				behavior_measure_uri = c(),
				before = c(),
				after = c(),
				yearchange = c(),
				startedAt = c(),
				endedAt = c(),
				beforeLaw = c(),
				afterLaw = c(),
				years = c()
				));
				
	for(state in states){
		for(behavior in behaviors){
			for(law in laws){
				r = try(getderivedset(state,behavior,law));
				if (is.data.frame(r)) {
					result = rbind(result, r);
				} else {
					error = data.frame(cbind(state=state, behavior=behavior, law=law, error=gettext(r)));
					errors = rbind(errors, error);
				}
			}
		}
	}

#}

stats = NULL;
for (behavior in levels(result$behavior_measure_uri)) {
	print(behavior);
	db = result[which(result$behavior_measure_uri==behavior),]
	for (law in levels(db$law_measure_uri)) {
		print(law)
		d = db[which(db$law_measure_uri == law),]
		meanChange = mean(d$change);
		testResult = t.test(as.numeric(as.character(d$before)), as.numeric(as.character(d$after)),paired=TRUE)
		stats = rbind(stats,cbind(behavior=behavior,
							law=law,
							n=length(rownames(d)), 
							t=testResult$statistic, 
							mean.change=meanChange,
							p.value=testResult$p.value))
	}
}

write.csv(stats,"stats.csv",row.names=F)
write.csv(result,"splits.csv",row.names=F)

# test it!

#auto_derived_set()