#!/bin/sh

# Use the internal K8s DNS to reach your Elasticsearch service
ES_URL="http://elasticsearch:9200"

# Query ES for errors in the last 5 mins
COUNT=$(curl -s -X POST "$ES_URL/filebeat-*/_count" -H 'Content-Type: application/json' -d '{
  "query": {
    "bool": {
      "must": [
        { "match": { "message": "error" } },
        { "range": { "@timestamp": { "gte": "now-5m" } } }
      ]
    }
  }
}' | grep -o '"count":[0-9]*' | cut -d: -f2)

# Failsafe
if [ -z "$COUNT" ]; then
  echo "UNKNOWN - Failed to connect to Elasticsearch."
  exit 3
fi

# Alert Logic (Threshold > 10)
if [ "$COUNT" -gt 10 ]; then
  echo "CRITICAL - $COUNT error logs found in the last 5 minutes!"
  exit 2
else
  echo "OK - $COUNT error logs found (Threshold is 10)."
  exit 0
fi