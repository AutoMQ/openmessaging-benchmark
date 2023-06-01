[placement_manager]
%{ for i, instance in concat(pm, mixed_pm_ctrl) ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i } pm_name=pm_${ i }
%{ endfor ~}

[data_node]
%{ for i, instance in concat(dn, mixed_dn_bkr) ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i }
%{ endfor ~}

[controller]
%{ for i, instance in concat(ctrl, mixed_pm_ctrl) ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i } kafka_id=${ i + 1 }
%{ endfor ~}

[broker]
%{ for i, instance in concat(bkr, mixed_dn_bkr) ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i } kafka_id=${ i + 1 + length(ctrl) + length(mixed_pm_ctrl) }
%{ endfor ~}

[client]
%{ for i, instance in client ~}
${ instance.public_ip } ansible_user=${ ssh_user } private_ip=${ instance.private_ip } index=${ i }
%{ endfor ~}
