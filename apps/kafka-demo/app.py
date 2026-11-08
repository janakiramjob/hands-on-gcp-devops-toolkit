"""Kafka demo app. One image, two modes selected by the MODE env var.

MODE=producer
  BURST      messages sent immediately at start (default 0)
  RATE       steady messages/second after the burst; 0 = exit after the burst (default 0)
  KEYS       number of distinct message keys (default 20)
MODE=consumer
  GROUP              consumer group (default orders-consumer)
  PROCESS_DELAY_MS   simulated work per message (default 200)
  Offsets are committed manually after each message; SIGTERM finishes the
  current message, commits, and leaves the group cleanly.
Common: KAFKA_BOOTSTRAP, TOPIC
"""
import json
import logging
import os
import signal
import sys
import time

from confluent_kafka import Consumer, KafkaError, Producer

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("kafka-demo")

MODE = os.environ.get("MODE", "").lower()
BOOTSTRAP = os.environ.get("KAFKA_BOOTSTRAP", "demo-kafka-bootstrap.kafka.svc:9092")
TOPIC = os.environ.get("TOPIC", "orders")
BURST = int(os.environ.get("BURST", "0"))
RATE = float(os.environ.get("RATE", "0"))
KEYS = int(os.environ.get("KEYS", "20"))
GROUP = os.environ.get("GROUP", "orders-consumer")
DELAY_S = int(os.environ.get("PROCESS_DELAY_MS", "200")) / 1000.0

stop = False


def _on_signal(signum, _frame):
    global stop
    log.info("signal %s received, shutting down after current message", signum)
    stop = True


signal.signal(signal.SIGTERM, _on_signal)
signal.signal(signal.SIGINT, _on_signal)


def run_producer():
    producer = Producer({"bootstrap.servers": BOOTSTRAP, "acks": "all", "linger.ms": 20})
    state = {"sent": 0, "failed": 0}

    def on_delivery(err, _msg):
        if err is not None:
            state["failed"] += 1
        else:
            state["sent"] += 1

    def send(i):
        key = f"customer-{i % KEYS}"
        value = json.dumps({"order_id": i, "customer": key, "ts": time.time()})
        while True:
            try:
                producer.produce(TOPIC, key=key, value=value, on_delivery=on_delivery)
                return
            except BufferError:  # local queue full: let delivery reports drain it
                producer.poll(0.2)

    log.info("producer: topic=%s burst=%d rate=%s/s keys=%d", TOPIC, BURST, RATE, KEYS)
    i = 0
    while i < BURST and not stop:
        send(i)
        i += 1
        producer.poll(0)
    producer.flush(30)
    log.info("burst done: delivered=%d failed=%d", state["sent"], state["failed"])

    if RATE > 0:
        interval = 1.0 / RATE
        next_at = time.monotonic()
        last_log = time.monotonic()
        while not stop:
            send(i)
            i += 1
            producer.poll(0)
            next_at += interval
            time.sleep(max(0.0, next_at - time.monotonic()))
            if time.monotonic() - last_log > 30:
                log.info("steady: delivered=%d failed=%d", state["sent"], state["failed"])
                last_log = time.monotonic()
        producer.flush(30)
    log.info("producer exit: delivered=%d failed=%d", state["sent"], state["failed"])


def run_consumer():
    consumer = Consumer({
        "bootstrap.servers": BOOTSTRAP,
        "group.id": GROUP,
        "enable.auto.commit": False,
        "auto.offset.reset": "earliest",
        "partition.assignment.strategy": "cooperative-sticky",
    })
    consumer.subscribe([TOPIC])
    log.info("consumer: topic=%s group=%s delay=%.3fs", TOPIC, GROUP, DELAY_S)
    done = 0
    last_log = time.monotonic()
    try:
        while not stop:
            msg = consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                if msg.error().code() != KafkaError._PARTITION_EOF:
                    log.warning("consumer error: %s", msg.error())
                continue
            time.sleep(DELAY_S)  # simulated work
            consumer.commit(message=msg, asynchronous=False)
            done += 1
            if time.monotonic() - last_log > 10:
                log.info("processed=%d (last: partition=%d offset=%d)", done, msg.partition(), msg.offset())
                last_log = time.monotonic()
    finally:
        consumer.close()  # leaves the group so partitions rebalance immediately
        log.info("consumer exit: processed=%d", done)


if __name__ == "__main__":
    if MODE == "producer":
        run_producer()
    elif MODE == "consumer":
        run_consumer()
    else:
        log.error("MODE must be 'producer' or 'consumer' (got %r)", MODE)
        sys.exit(2)
