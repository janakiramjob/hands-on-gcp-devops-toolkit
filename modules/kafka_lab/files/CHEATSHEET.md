# Kafka + KEDA lab cheatsheet (files live in ~/kafka-lab on the controlplane)

All Kafka CLI runs inside the `kafka-client` pod:

    K="kubectl -n kafka exec -i kafka-client --"
    B=demo-kafka-bootstrap:9092

## Topics (created via KafkaTopic CRs; auto-create is OFF)
    $K bin/kafka-topics.sh --bootstrap-server $B --list
    $K bin/kafka-topics.sh --bootstrap-server $B --describe --topic orders

## Produce keyed messages (key:value)
    printf 'c1:hello\nc2:world\nc1:again\n' | $K bin/kafka-console-producer.sh --bootstrap-server $B --topic orders \
        --property parse.key=true --property key.separator=:

## Consume with a group (use a different group than orders-consumer to avoid stealing KEDA's work)
    $K bin/kafka-console-consumer.sh --bootstrap-server $B --topic orders --group cli-test --from-beginning \
        --property print.key=true --property print.partition=true --timeout-ms 10000

## Lag, offsets, group management
    $K bin/kafka-consumer-groups.sh --bootstrap-server $B --list
    $K bin/kafka-consumer-groups.sh --bootstrap-server $B --describe --group orders-consumer
    # group must have no active members (consumer scaled to 0) to reset:
    $K bin/kafka-consumer-groups.sh --bootstrap-server $B --group orders-consumer --topic orders --reset-offsets --to-earliest --dry-run
    $K bin/kafka-consumer-groups.sh --bootstrap-server $B --group orders-consumer --topic orders --reset-offsets --to-earliest --execute
    $K bin/kafka-consumer-groups.sh --bootstrap-server $B --delete --group cli-test

## The same lag from Kafka Exporter
    kubectl -n kafka port-forward deploy/demo-kafka-exporter 9404 &
    curl -s localhost:9404/metrics | grep kafka_consumergroup_lag

## Scale test (0 -> N -> 0)
    kubectl -n demo delete job orders-burst --ignore-not-found
    kubectl apply -f ~/kafka-lab/loadtest-job.rendered.yaml   # 3000 messages burst
    ~/kafka-lab/watch.sh all
    # steady stream instead:  kubectl -n demo scale deploy/producer --replicas=1   (5 msg/s)
    # tune: edit lagThreshold / cooldownPeriod in manifests/scaledobject.yaml, kubectl apply -f

## Grafana / Prometheus (port-forward, then browse http://localhost:3000 — admin / prom-operator)
    kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
    kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090
