[server]
%{ for i, instance in server ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i } kafka_id=${ server_kafka_ids[i] } data_volume=${ length(instance.ebs_block_device) > 0 ? "/dev/disk/by-id/vol${ replace(instance.ebs_block_device[0].volume_id, "vol-", "") }" : "/dev/null" } data_volume_iops=${ length(instance.ebs_block_device) > 0 ? instance.ebs_block_device[0].iops : 0 }
%{ endfor ~}

[broker]
%{ for i, instance in broker ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i } kafka_id=${ broker_kafka_ids[i] } data_volume=${ length(instance.ebs_block_device) > 0 ? "/dev/disk/by-id/vol${ replace(instance.ebs_block_device[0].volume_id, "vol-", "") }" : "/dev/null" } data_volume_iops=${ length(instance.ebs_block_device) > 0 ? instance.ebs_block_device[0].iops : 0 }
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
cloud_provider=${ cloud_provider }
s3_endpoint=https://s3.${ s3_region }.${ aws_domain }
s3_region=${ s3_region }
s3_bucket=${ s3_bucket }
cluster_id=${ cluster_id }
access_key=${ access_key }
secret_key=${ secret_key }
role_name=${ role_name }
network_bandwidth=${ network_bandwidth }
s3_wal_enabled=${ s3_wal_enabled }
