source .env.sh

# Some local properties
DATASOURCE_DIR=$(pwd)/dataset
NUM_OF_RUNS=0

# Utility functions
check_service () {
	echo -ne '\n'
	echo $1 $ELASTIC_VERSION must be available on $2
	echo -ne "Waiting for $1"

	until curl -u elastic:$ELASTIC_PASSWORD -s "$2" | grep "$3" > /dev/null; do
		  sleep 1
			echo -ne '.'
	done

	echo -ne '\n'
	echo $1 is now up.
}

# Curl Delete call Param 1 is the Full URL, Param 2 is optional text
# curl_delete "$ELASTICSEARCH_URL/foo*" "Fancy text"
# curl_delete "$ELASTICSEARCH_URL/foo*"
curl_delete () {
	if [ -z "$2" ] ; then
		echo "Calling DELETE $1"
	else 
	  echo $2
	fi
  curl -XDELETE "$1" -u elastic:$ELASTIC_PASSWORD -H 'kbn-xsrf: true' ; echo
}

# Curl Post call Param 1 is the Full URL, Param 2 is a json file, Param 3 is optional text
# 
curl_post () {
	if [ -z "$3" ] ; then
		echo "Calling POST $1"
	else 
	  echo $3
	fi
  curl -XPOST "$1" -u elastic:$ELASTIC_PASSWORD -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d"@$2" ; echo
}

# Curl Post call Param 1 is the Full URL, Param 2 is a json file, Param 3 is optional text
# 
curl_post_form () {
	if [ -z "$3" ] ; then
		echo "Calling POST FORM $1"
	else 
	  echo $3
	fi
  curl -XPOST "$1" -u elastic:$ELASTIC_PASSWORD -H 'kbn-xsrf: true' --form file="@$2" ; echo
}

# Curl Put call Param 1 is the Full URL, Param 2 is a json file, Param 3 is optional text
# 
curl_put () {
	if [ -z "$3" ] ; then
		echo "Calling PUT $1"
	else 
	  echo $3
	fi
  curl -XPUT "$1" -u elastic:$ELASTIC_PASSWORD -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d"@$2" ; echo
}

# Curl Get call Param 1 is the Full URL, Param 2 is optional text
# 
curl_get () {
	if [ -z "$2" ] ; then
		echo "Calling GET $1"
	else 
	  echo $2
	fi
  curl -XGET "$1" -u elastic:$ELASTIC_PASSWORD ; echo
}

# Start of the script
echo Installation script for Searchable Snapshots demo with Elastic $ELASTIC_VERSION

echo "##################"
echo "### Pre-checks ###"
echo "##################"

if [ ! -e $DATASOURCE_DIR ] ; then
    echo "Creating $DATASOURCE_DIR dir"
    mkdir $DATASOURCE_DIR
fi

if [ -z "$CLOUD_ID" ] ; then
	echo "We are running a local demo. If you did not start Elastic yet, please run:"
	echo "docker-compose up"
fi

check_service "Elasticsearch" "$ELASTICSEARCH_URL" "\"number\" : \"$ELASTIC_VERSION\""
check_service "Kibana" "$KIBANA_URL/app/home#/" "<title>Elastic</title>"

echo -ne '\n'
echo "################################"
echo "### Configure Cloud Services ###"
echo "################################"
echo -ne '\n'

curl_delete "$ELASTICSEARCH_URL/demo-person-old"
curl_delete "$ELASTICSEARCH_URL/_snapshot/elastic-bytes/demo"

echo -ne '\n'
echo "#####################################"
echo "### Initialize the person Dataset ###"
echo "#####################################"
echo -ne '\n'

echo "Creating index demo-person if needed"
curl_put "$ELASTICSEARCH_URL/demo-person" "elasticsearch-config/demo-person.json"

if [ ! -e $DATASOURCE_DIR/bulk-person.ndjson ] ; then
  echo "Generating the bulk request"
	# It has been generated using the person injector (not public though)
	# java -jar injector-7.0.jar --console --nb 10000 > $DATASOURCE_DIR/persons.json
	cat $DATASOURCE_DIR/persons.json | jq --slurp -c '.[] | { index : {  }}, { name: .name, dateofbirth: .dateofbirth, address: .address }' > $DATASOURCE_DIR/bulk-person.ndjson
fi

echo "Ingesting $NUM_OF_RUNS times 10 000 persons"
for i in $(seq 1 $NUM_OF_RUNS)
do
	echo "-> Run $i"
	curl -XPOST "$ELASTICSEARCH_URL/demo-person/_bulk" -s -u elastic:$ELASTIC_PASSWORD -H 'Content-Type: application/x-ndjson' --data-binary "@$DATASOURCE_DIR/bulk-person.ndjson" | jq '{took: .took, errors: .errors}' ; echo
done

echo -ne '\n'
echo "#############################"
echo "### Install Canvas Slides ###"
echo "#############################"
echo -ne '\n'

curl_post_form "$KIBANA_URL/api/saved_objects/_import?overwrite=true" "kibana-config/canvas.ndjson"

echo -ne '\n'
echo "#####################"
echo "### Demo is ready ###"
echo "#####################"
echo -ne '\n'

open "$KIBANA_URL/app/canvas#/"

echo "If not yet there, paste the following script in Dev Tools:"
cat elasticsearch-config/devtools-script.json
echo -ne '\n'

