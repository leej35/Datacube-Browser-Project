getExpressionRDF <- function(data) {
   
  header = paste("
@prefix dataset: <http://logd.tw.rpi.edu/source/popscigrid/dataset/youth_tobacco_policy_effects/>.@prefix popscigrid: <http://logd.tw.rpi.edu/source/popscigrid/>.@prefix impacteen: <http://health.tw.rpi.edu/source/impacteen-org/dataset/tobacco-control-policy-and-prevalence/>.
@prefix efo: <http://www.ebi.ac.uk/efo/>.
@prefix obo: <http://purl.obolibrary.org/obo#>.
@prefix ncicb: <http://ncicb.nci.nih.gov/xml/owl/EVS/Thesaurus.owl#>.

popscigrid:dataset/youth_tobacco_policy_effects a void:Dataset;
prov:wasDerivedFrom impacteen:version/2012-Jan-14. 

");

i=0;
body = NULL;
tuple = NULL;

for(i in 1:dim(data)[1]){
	
	stateURI = data[i,"state_measure_uri"];
	lawURI = data[i,"law_measure_uri"];
	behaviorURI = data[i,"behavior_measure_uri"];
	
	before = data[i,"before"];
	after = data[i,"after"];
	startYear = data[i,"startedAt"];
	endYear = data[i,"endedAt"];
	beforeLawValue = data[i,"beforeLaw"];
	afterLawValue = data[i,"afterLaw"];
	years = as.character(data[i,"yearString"]$yearString);
	
	lawLabel = strsplit(as.character(lawURI$law_measure_uri),"\\/")[[1]]
	lawLabel = lawLabel[max(length(lawLabel))];
	lawLabel = substr(lawLabel,1,nchar(lawLabel)-1);

	stateLabel = strsplit(as.character(stateURI$state_measure_uri),"\\/")[[1]]
	stateLabel = stateLabel[max(length(stateLabel))];
	stateLabel = substr(stateLabel,1,nchar(stateLabel)-1);

	behaviorLabel = strsplit(as.character(behaviorURI$behavior_measure_uri),"\\/")[[1]]
	behaviorLabel = behaviorLabel[max(length(behaviorLabel))];
	behaviorLabel = substr(behaviorLabel,1,nchar(behaviorLabel)-1);

	yearstr = strsplit(years,"\\/")

	behaviorProv = NULL;	
	for(year in yearstr[[1]]){
		behaviorProv = paste(behaviorProv,"\t\t  impacteen:datum_People/",behaviorLabel,"/",stateLabel,"/",as.numeric(year),",\n",sep="")
	}
	behaviorProv = substr(behaviorProv,1,nchar(behaviorProv)-2)

	lawProv = NULL;	
	for(year in yearstr[[1]]){
		lawProv = paste(lawProv,"\t\t  impacteen:datum_People/",lawLabel,"/",stateLabel,"/",as.numeric(year),",\n",sep="")
	}
	lawProv = substr(lawProv,1,nchar(lawProv)-2)
		
	tuple = paste("
		dataset:",lawLabel,"/",stateLabel,"/",startYear,"-",endYear,"
		  dcterms:isReferencedBy popscigrid:dataset/youth_tobacco_policy_effects;
		  void:inDataset popscigrid:dataset/youth_tobacco_policy_effects;
		  a datacube:SingularValue;
		  prov:location dbpedia:",stateLabel,";
		  prov:specializationOf dbpedia:",stateLabel,";
		  prov:generatedAtTime \"",startYear,"\"^^xsd2:gYear ;
		  measure:Rate_of_change_in_",behaviorLabel," ",before,";
		  measure:",lawLabel, " \"",beforeLawValue,"\";
		  prov:invalidatedAtTime \"",endYear,"\"^^xsd2:gYear ;
		  prov:wasDerivedFrom\n",behaviorProv,";\n",lawProv,";
		measure:Coefficient_Before_",lawLabel," obo:has_role ncicb:Change.
		\n\n","

		dataset:",lawLabel,"/",stateLabel,"/",startYear,"-",endYear,"
		  dcterms:isReferencedBy popscigrid:dataset/youth_tobacco_policy_effects;
		  void:inDataset popscigrid:dataset/youth_tobacco_policy_effects;
		  a datacube:SingularValue;
		  prov:location dbpedia:",stateLabel,";
		  prov:specializationOf dbpedia:",stateLabel,";
		  prov:generatedAtTime \"",startYear,"\"^^xsd2:gYear;
		  measure:Rate_of_change_in_",behaviorLabel," ",after,";
		  measure:",lawLabel, " \"",afterLawValue,"\";
		  prov:invalidatedAtTime \"",endYear,"\"^^xsd2:gYear;
		  prov:wasDerivedFrom\n",behaviorProv,";\n",lawProv,";
		measure:Coefficient_After_",lawLabel," obo:has_role ncicb:Control.
		\n\n\n\n"
		
		,sep="");
	body = paste(body,tuple);
}
  return(paste(header, body, sep=""))
}

rdf<-getExpressionRDF(result)
fileConn<-file("output.txt")
writeLines(c(rdf), fileConn)
close(fileConn)