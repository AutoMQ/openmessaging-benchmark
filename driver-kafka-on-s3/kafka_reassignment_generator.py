import argparse
import json


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate Kafka reassignment json file")
    parser.add_argument("-t", "--topic", type=str,
                        required=True, help="Topic name")
    parser.add_argument("-p", "--partition", type=str, required=True,
                        help="Two numbers separated by comma indicating the start partition and end partition")
    parser.add_argument("-n", "--node", type=int, required=True,
                        help="Node id to move the partitions to")

    args = parser.parse_args()
    topic = args.topic
    partition = range(int(args.partition.split(",")[0]), int(args.partition.split(",")[1])
                      )
    node = args.node

    reassignment = {
        "version": 1,
        "partitions": [
            {
                "topic": topic,
                "partition": p,
                "replicas": [node]
            } for p in partition
        ]
    }

    print(json.dumps(reassignment))
