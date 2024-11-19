[server]
%{ for i, instance in server ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i } kafka_id=${ server_kafka_ids[i] } data_volume=/dev/vdb data_volume_iops=2800
%{ endfor ~}

[broker]
%{ for i, instance in broker ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i } kafka_id=${ broker_kafka_ids[i] } data_volume=/dev/vdb data_volume_iops=2800
%{ endfor ~}

[client]
%{ for i, instance in client ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i }
%{ endfor ~}

[telemetry]
%{ for i, instance in telemetry ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip }
%{ endfor ~}

[all:vars]
cloud_provider=aliyun
s3_endpoint=https://cos.${ cos_region }.myqcloud.com
s3_region=${ cos_region }
s3_bucket=${ cos_bucket }
cluster_id=${ cluster_id }
access_key=${ secret_id }
secret_key=${ secret_key }
role_name=${ role_name }
network_bandwidth=${ network_bandwidth }
