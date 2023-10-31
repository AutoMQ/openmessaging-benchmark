import json
import re
from typing import Generator

import boto3


def describe_scaling_activities(asg_name: str):
    as_client = boto3.client('autoscaling')
    paginator = as_client.get_paginator('describe_scaling_activities')
    page_iterator = paginator.paginate(
        AutoScalingGroupName=asg_name,
        IncludeDeletedGroups=True
    )
    for page in page_iterator:
        for activity in page['Activities']:
            yield activity


def get_all_instances_in_asg(asg_name: str) -> Generator[str, None, None]:
    '''
    :param asg_name: name of the autoscaling group
    :return: a generator of instance ids, ordered by launch time descending
    '''
    for activity in describe_scaling_activities(asg_name):
        if activity['StatusCode'] == 'Successful' and activity['Description'].startswith('Launching a new EC2 instance'):
            instance_id = re.search(
                r'Launching a new EC2 instance: (i-\w+)', activity['Description']).group(1)
            yield instance_id


def generate_cloud_watch_source(asg_name: str, controller_ids: "list[str]", broker_ids: "list[str]", client_ids: "list[str]", threshold: int, detailed: bool = False):
    # TODO: colorize the metrics
    cloud_watch_source = {
        "title": "Kafka on S3 Metrics",
        "view": "timeSeries",
        "stacked": False,
        "period": 60,
        "annotations": {
            "horizontal": [
                {
                    "label": "Network Threshold ({} bytes/s)".format(threshold),
                    "value": threshold,
                    "yAxis": "left",
                }
            ]
        },
        "legend": {
            "position": "right",
        },
        "liveData": True,
        "yAxis": {
            "left": {
                "label": "Network Throughput (bytes/s)",
                "min": 0,
                "showUnits": False,
            },
            "right": {
                "label": "Broker Count",
                "min": 0,
                "showUnits": False,
            }
        },
    }

    clno = "clientNetworkOut"
    clnt = "clientNetworkThroughput"

    cni = "controllerNetworkIn"
    cno = "controllerNetworkOut"
    cnt = "controllerNetworkThroughput"
    cnta = "controllerNetworkThroughputAvg"

    bc = "brokerCount"
    bni = "brokerNetworkIn"
    bno = "brokerNetworkOut"
    bnt = "brokerNetworkThroughput"
    bnta = "brokerNetworkThroughputAvg"
    metrics = []

    # client group
    clno_list = []
    for i, clid in enumerate(client_ids):
        metrics.append(["AWS/EC2", "NetworkOut", "InstanceId", clid,
                        {"id": f"{clno}{i}", "label": "", "stat": "Sum", "visible": False}])
        metrics.append([{"id": f"{clnt}{i}", "expression": f"{clno}{i}/DIFF_TIME({clno}{i})",
                       "label": "", "visible": False}])
        clno_list.append(f"{clno}{i}")
    clno_list_str = ', '.join(clno_list)
    metrics.append([{"id": clnt, "expression": f"SUM([ {clno_list_str} ])",
                   "label": "total network throughput of all clients", "visible": not detailed}])

    # each controller
    cnt_list = []
    for i, cid in enumerate(controller_ids):
        metrics.append(["AWS/EC2", "NetworkIn", "InstanceId", cid,
                        {"id": f"{cni}{i}", "label": "", "stat": "Sum", "visible": False}])
        metrics.append(["AWS/EC2", "NetworkOut", "InstanceId", cid,
                        {"id": f"{cno}{i}", "label": "", "stat": "Sum", "visible": False}])
        metrics.append([{"id": f"{cnt}{i}", "expression": f"MAX([ {cni}{i}/DIFF_TIME({cni}{i}), {cno}{i}/DIFF_TIME({cno}{i}) ])",
                         "label": f"network throughput of controller {i}", "visible": detailed}])
        cnt_list.append(f"{cnt}{i}")
    # controller group
    cnt_list_str = ', '.join(cnt_list)
    metrics.append([{"id": cnta, "expression": f"AVG([ {cnt_list_str} ])",
                   "label": "average network throughput of each controller", "visible": True}])

    # broker count
    metrics.append(["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", asg_name,
                   {"id": bc, "label": "broker count", "stat": "Average", "yAxis": "right", "visible": True}])

    # each broker
    for i, bid in enumerate(broker_ids):
        metrics.append(["AWS/EC2", "NetworkIn", "InstanceId", bid,
                        {"id": f"{bni}{i}", "label": "", "stat": "Sum", "visible": False}])
        metrics.append(["AWS/EC2", "NetworkOut", "InstanceId", bid,
                        {"id": f"{bno}{i}", "label": "", "stat": "Sum", "visible": False}])
        metrics.append([{"id": f"{bnt}{i}", "expression": f"MAX([ {bni}{i}/DIFF_TIME({bni}{i}), {bno}{i}/DIFF_TIME({bno}{i}) ])",
                         "label": f"network throughput of broker {i}", "visible": detailed}])
    # broker group
    metrics.append(["AWS/EC2", "NetworkIn", "AutoScalingGroupName", asg_name,
                    {"id": bni, "label": "", "stat": "Sum", "visible": False}])
    metrics.append(["AWS/EC2", "NetworkOut", "AutoScalingGroupName", asg_name,
                    {"id": bno, "label": "", "stat": "Sum", "visible": False}])
    metrics.append([{"id": bnt, "expression": f"MAX([ {bni}/DIFF_TIME({bni}), {bno}/DIFF_TIME({bno}) ])",
                     "label": "", "visible": False}])
    metrics.append([{"id": bnta, "expression": f"{bnt}/{bc}",
                   "label": "average network throughput of each broker", "visible": True}])

    metrics.sort(key=lambda m: m[-1]["visible"], reverse=True)
    cloud_watch_source["metrics"] = metrics

    return cloud_watch_source


if __name__ == '__main__':
    # TODO
    controller_list = [
        "i-0e7b082b5a6d70446",
        "i-01c48a60456c0b2a5",
        "i-046c4b4da8efd2e79",
    ]
    client_list = [
        "i-00353c49a6dd864e6",
        "i-00463a3b17b3ff4c5",
    ]
    asg_name = "stack-kos-broker-asg-cn-northwest-1-e4515e77801c42d5-spot-stack-group-kos-lp-cn-northwest-1-e4515e77801c42d5-broker-zone-0"

    broker_list = list(reversed(list(get_all_instances_in_asg(asg_name))))
    source = generate_cloud_watch_source(
        asg_name, controller_list, broker_list, client_list, 83859236, False)
    print(json.dumps(source))
