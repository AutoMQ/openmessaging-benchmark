[server]
%{ for i, instance in server ~}
${ server_public_ips[i] } ansible_user=${ ssh_user } private_ip=${ instance.internal_ip } index=${ i } kafka_id=${ server_kafka_ids[i] } data_volume=/dev/vdb data_volume_iops=2800
%{ endfor ~}

[broker]
%{ for i, instance in broker ~}
${ broker_public_ips[i] } ansible_user=${ ssh_user } private_ip=${ instance.internal_ip } index=${ i } kafka_id=${ broker_kafka_ids[i] } data_volume=/dev/vdb data_volume_iops=2800
%{ endfor ~}

[client]
%{ for i, instance in client ~}
${ client_public_ips[i] } ansible_user=${ ssh_user } private_ip=${ instance.internal_ip } index=${ i }
%{ endfor ~}

[telemetry]
%{ for i, instance in telemetry ~}
${ telemetry_public_ips[i] } ansible_user=${ ssh_user } private_ip=${ instance.internal_ip }
%{ endfor ~}

[all:vars]
cloud_provider=baiducloud
s3_endpoint=https://s3.${ bos_region }.bcebos.com
s3_region=${ bos_region }
s3_bucket=${ bos_bucket }
cluster_id=${ cluster_id }
access_key=${ access_key }
secret_key=${ secret_key }
role_name=${ role_name }
network_bandwidth=${ network_bandwidth }
