# demo-metrics-analytics

This demo presents a guide to performing analytics on Prometheus metrics using Presto, the Prometheus Presto Connector and Superset to run analytical SQL queries against Prometheus metrics and visualize them.

The current demo supports Presto and will support Spark once the work in progress Spark connector for Promtheus metrics is available.

Major credit to [Brett Tofel](https://github.com/bentito) for the Presto Prometheus Connector.

## Demo

### 1. Start containers and setup

Start containers and begin Apache Superset user account setup:
```shell
$ make start
```

You will be prompted to create a username and password for Apache Superset. Once done it will run migrations and complete. Now you have docker containers running Presto and Superset. Use `make docker_ps` to see currently running containers:

```shell
$ make docker_ps
docker-compose ps
              Name                             Command                  State               Ports
----------------------------------------------------------------------------------------------------------
demo-metrics-analytics_envoy_1      /usr/bin/envoy --config-pa ...   Up
demo-metrics-analytics_presto_1     /usr/lib/presto/bin/run-presto   Up             0.0.0.0:8080->8080/tcp
demo-metrics-analytics_superset_1   gunicorn superset.app:crea ...   Up (healthy)   0.0.0.0:8088->8088/tcp
```

To restart you can use `make docker_stop` and `make docker_start` after setup.

### 2. Make Prometheus HTTP API available

To make Presto able to query Prometheus metrics you need to make available or port forward the Prometheus HTTP API so that it is available at `localhost:9090`. 

If have the Prometheus HTTP API available from a pod on Kubernetes you can port forward like so (in this example port 9090 local, port 7201 remote):
```shell
$ kubectl port-forward m3coordinator-read-68b94b4fcd-8brpn 9090:7201
```

This can be changed in `envoy/etc/envoy.yaml` from `host.docker.internal` and port `9090` if you wish to directly route the Prometheus queries to somewhere else. 


### 3. Add Presto database to Superset

Next up we'll create the Presto database in Superset. Navigate to the following URL: 
[http://localhost:8088/databaseview/add](http://localhost:8088/databaseview/add).

Enter the following:
```
Database: Presto
SQLAlchemy URI: presto://presto:8080/prometheus/default
```

No need to fill out anything else, scroll to bottom of page and click save.

### 4. Issue some queries

Now you can visit the SQL editor and execute some queries: [http://localhost:8088/superset/sqllab](http://localhost:8088/superset/sqllab).

Select "Presto" for database and "default" for schema.

You can now issue queries as such:
```sql
SELECT "labels", "timestamp", "value"
FROM "default"."container_memory_rss"
WHERE element_at(labels,'k8s_namespace') IS NOT NULL
    AND labels['k8s_namespace'] = 'some-kube-namespace'
    AND timestamp > (NOW() - INTERVAL '7' day) 
ORDER BY timestamp ASC
```

This query is quite basic, you can of course perhaps try some much more complex queries.

Then try visualizing the result of a query as per the talk's demonstration with Superset charts.

### 5. Visit the Presto 

To visualize the query execution, parallelization and splitting visit the Presto admin console and user "admin" login: [http://localhost:8080/](http://localhost:8080/).

## Notes

### Prometheus 

Queries are chunked by a day interval using the default configuration. You can change this at `presto/etc/catalog/prometheus.properties`.

Here's the default configuration:
```
connector.name=prometheus
prometheus.uri=http://envoy:9090
prometheus.query.chunk.size.duration=1d
prometheus.max.query.range.duration=30d
prometheus.cache.ttl=30s
```

### Envoy

One might ask why Envoy is part of this demo. Envoy runs in this demo so that headers can be added to the requests from Presto to the Prometheus HTTP API which allows restricting the metrics selected further than what's available with the Presto Prometheus Connector currently. A current limitation of the Presto Prometheus Connector is that it always selects all metrics for a given metric name (e.g. `up`) and applies any `WHERE` clause after all metrics have been returned without applying any label matching as part of the query to the Prometheus HTTP API. 

The configured Envoy specifies the header `M3-Restrict-By-Tags-JSON` which allows an [M3](https://m3db.io)'s Prometheus HTTP API backend to restrict metrics selected by certain labels before being returned to Presto for faster queries, for more on this [see the relevant documentation](https://m3db.io/docs/m3query/api/query/). You may edit `envoy/etc/envoy.yaml` to modify this behavior.
