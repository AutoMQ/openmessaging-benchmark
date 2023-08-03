[placement_driver]
%{ for i, instance in concat(pd, mixed_pd_ctrl) ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i } pd_name=pd_${ i }
%{ endfor ~}

[range_server]
%{ for i, instance in concat(rs, mixed_rs_bkr) ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i }
%{ endfor ~}

[controller]
%{ for i, instance in concat(ctrl, mixed_pd_ctrl) ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i } kafka_id=${ i + 1 }
%{ endfor ~}

[broker]
%{ for i, instance in concat(bkr, mixed_rs_bkr) ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i } kafka_id=${ i + 1 + length(ctrl) + length(mixed_pd_ctrl) }
%{ endfor ~}

[client]
%{ for i, instance in client ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i }
%{ endfor ~}
