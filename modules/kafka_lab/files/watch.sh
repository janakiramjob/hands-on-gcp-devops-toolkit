#!/usr/bin/env bash
# Watch the scale 0 -> N -> 0 cycle.  Usage: ./watch.sh [lag|hpa|pods|events|all]
what="${1:-all}"
lag()    { kubectl -n kafka exec kafka-client -- bin/kafka-consumer-groups.sh --bootstrap-server demo-kafka-bootstrap:9092 --describe --group orders-consumer 2>&1 | sed '/^$/d'; }
hpa()    { kubectl -n demo get hpa,scaledobject; }
pods()   { kubectl -n demo get pods -o wide; }
events() { kubectl -n demo get events --sort-by=.lastTimestamp | tail -12; }
case "$what" in
  lag|hpa|pods|events) while true; do clear; date; "$what"; sleep 3; done ;;
  all) while true; do clear; date; echo "== scaledobject / hpa"; hpa; echo; echo "== consumer pods"; pods; echo; echo "== lag"; lag; echo; echo "== events"; events; sleep 4; done ;;
  *) echo "usage: $0 [lag|hpa|pods|events|all]"; exit 1 ;;
esac
