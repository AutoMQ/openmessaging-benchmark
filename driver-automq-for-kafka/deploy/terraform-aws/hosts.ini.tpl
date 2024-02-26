[server]
%{ for i, instance in server ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i } kafka_id=${ i + 1 } data_volume=nvme-Amazon_Elastic_Block_Store_vol${ replace(tolist(instance.ebs_block_device)[0].volume_id, "vol-", "") } data_volume_iops=${ tolist(instance.ebs_block_device)[0].iops }
%{ endfor ~}

[broker]
%{ for i, instance in broker ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i } kafka_id=${ i + 1 + length(server) } data_volume=nvme-Amazon_Elastic_Block_Store_vol${ replace(tolist(instance.ebs_block_device)[0].volume_id, "vol-", "") } data_volume_iops=${ tolist(instance.ebs_block_device)[0].iops }
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
s3_endpoint=https://s3.${ s3_region }.${ aws_domain }
s3_region=${ s3_region }
s3_bucket=${ s3_bucket }
