ARG  VERSION
FROM docker.elastic.co/elasticsearch/elasticsearch:$VERSION
ADD elasticsearch-config/service-account.json /tmp/service-account.json
RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install --batch repository-gcs
RUN /usr/share/elasticsearch/bin/elasticsearch-keystore create
RUN /usr/share/elasticsearch/bin/elasticsearch-keystore add-file gcs.client.demo.credentials_file /tmp/service-account.json

