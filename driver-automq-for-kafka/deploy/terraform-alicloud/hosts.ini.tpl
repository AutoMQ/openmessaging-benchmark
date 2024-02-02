[server]
%{ for i, instance in server ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.primary_ip_address } index=${ i } kafka_id=${ i + 1 }
%{ endfor ~}

[broker]
%{ for i, instance in broker ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.primary_ip_address } index=${ i } kafka_id=${ i + 1 + length(server) }
%{ endfor ~}

[client]
%{ for i, instance in client ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.primary_ip_address } index=${ i }
%{ endfor ~}

[telemetry]
%{ for i, instance in telemetry ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.primary_ip_address }
%{ endfor ~}

[all:vars]
s3_endpoint=https://${ oss_endpoint }
s3_region=${ oss_region }
s3_bucket=${ oss_bucket }
kafka_wal_path=/dev/vdb
