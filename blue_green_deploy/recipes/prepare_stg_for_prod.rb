if node[:opsworks][:instance][:layers][0].to_s == "#{node[:submodules][:frontend][:layer]}"
template "/var/www/frontend/current/start.sh" do
    source "start.erb"
    user "root"
    group "root"
    mode 777
variables(
    :mongo_url => node[:submodules][:frontend][:prod_mongo_url] ,
    :root_url => node[:submodules][:frontend][:prod_root_url],
    :mail_url => node[:submodules][:frontend][:prod_mail_url],
    :port => node[:submodules][:frontend][:internal_port],
    :meteor_setting_json => node[:submodules][:frontend][:prod_meteor_setting_json],
  )

end

node[:submodules][:frontend][:instance_count].times do |index|
  script "run_app_#{index}_container" do
    interpreter "bash"
    user "root"
    code <<-EOH
      docker restart app#{index}
    EOH
  end
end

template "/root/monitoring.sh" do
    source "monitoring.erb"
    user "root"
    group "root"
    mode 777
   variables(
    :env =>  node[:prod_env],
    :InstanceID => node[:opsworks][:instance][:aws_instance_id],
    :backend_instance => node[:opsworks][:layers]["#{node[:submodules][:backend][:layer]}"][:instances].first[0],
)
  end

cron 'process_monitoring' do
  minute '*/5'
  hour '*'
  weekday '*'
  user 'root'
  command "/bin/sh -x  /root/monitoring.sh >/dev/null 2>&1"
  action :create
end

instance_count=1
node[:opsworks][:layers]["#{node[:submodules][:frontend][:layer]}"][:instances].each do  |value|
if value[0] == node["opsworks"]["instance"]["hostname"]
bash "cloud_alarm" do
 user "root"
 group "root"
 code <<-EOH
aws cloudwatch put-metric-alarm --alarm-name #{node[:prod_env]}_App_#{instance_count} --alarm-description "Alarm when App count lessthan #{node[:prod_app_count_threshold]}" --metric-name  OnlineCount --namespace APP_Metrics --statistic Average --period 300 --threshold #{node[:prod_app_count_threshold]} --comparison-operator LessThanThreshold  --dimensions '[{"Name":"InstanceID","Value":"#{node[:opsworks][:instance][:aws_instance_id]}"},{"Name":"Env","Value":"Prod"},{"Name":"App_name","Value":"App"}]' --evaluation-periods 1 --alarm-actions #{node[:arn_sns_details]} --unit Count
aws cloudwatch put-metric-alarm --alarm-name #{node[:prod_env]}_Disk_Space_#{instance_count} --alarm-description "Alarm when Disk space exceeds #{node[:prod_disk_space_threshold]} percent" --metric-name  Disk_Space --namespace APP_Metrics --statistic Average --period 300 --threshold #{node[:prod_disk_space_threshold]} --comparison-operator GreaterThanThreshold  --dimensions '[{"Name":"InstanceID","Value":"#{node[:opsworks][:instance][:aws_instance_id]}"},{"Name":"Env","Value":"Prod"},{"Name":"App_name","Value":"Disk_Space"}]' --evaluation-periods 1 --alarm-actions #{node[:arn_sns_details]} --unit Percent
EOH
end
end
instance_count=instance_count+1
end


elsif node[:opsworks][:instance][:layers][0].to_s == "#{node[:submodules][:backend][:layer]}"
then
template "/var/www/backend/current/start.sh" do
    source "start.erb"
    user "root"
    group "root"
    mode 777
variables(
    :mongo_url => node[:submodules][:frontend][:prod_mongo_url] ,
    :root_url => node[:submodules][:frontend][:prod_root_url],
    :mail_url => node[:submodules][:frontend][:prod_mail_url],
    :port => node[:submodules][:frontend][:internal_port],
    :meteor_setting_json => node[:submodules][:frontend][:prod_meteor_setting_json],
    :json => node[:submodules][:backend][:prod_json],
    :cron_json => node[:submodules][:backend][:prod_cron_json],
    :backend_layer => node[:opsworks][:layers]["#{node[:submodules][:backend][:layer]}"][:instances].first[0],
  )

end

node[:submodules][:backend][:instance_count].times do |index|
  script "run_app_#{index}_container" do
    interpreter "bash"
    user "root"
    code <<-EOH
      docker restart app#{index}
    EOH
  end
if index = 0
if node[:opsworks][:layers]["#{node[:submodules][:backend][:layer]}"][:instances].first[0] == node["opsworks"]["instance"]["hostname"]
  template "/var/www/backend/current/cron.sh" do
      source "cron.erb"
      user "root"
      group "root"
      mode 777
   variables(
      :cron_json =>  node[:submodules][:backend][:prod_cron_json],
      :backend_layer => node[:opsworks][:layers]["#{node[:submodules][:backend][:layer]}"][:instances].first[0],
  )
    end
    script "run_cron_json" do
      interpreter "bash"
      user "root"
      code <<-EOH
        docker exec app0 sh cron.sh &
      EOH
    end
end
end
end

template "/root/monitoring.sh" do
    source "monitoring.erb"
    user "root"
    group "root"
    mode 777
   variables(
    :env =>  node[:prod_env],
    :InstanceID => node[:opsworks][:instance][:aws_instance_id],
    :backend_instance => node[:opsworks][:layers]["#{node[:submodules][:backend][:layer]}"][:instances].first[0],
)
  end

cron 'process_monitoring' do
  minute '*/5'
  hour '*'
  weekday '*'
  user 'root'
  command "/bin/sh -x  /root/monitoring.sh >/dev/null 2>&1"
  action :create
end

instance_count=1
node[:opsworks][:layers]["#{node[:submodules][:backend][:layer]}"][:instances].each do  |value|
if value[0] == node["opsworks"]["instance"]["hostname"]
bash "cloud_alarm" do
 user "root"
 group "root"
 code <<-EOH
aws cloudwatch put-metric-alarm --alarm-name #{node[:prod_env]}_Decider_#{instance_count} --alarm-description "Alarm when Decider count lessthan #{node[:prod_decider_count_threshold]}" --metric-name  OnlineCount --namespace APP_Metrics --statistic Average --period 300 --threshold #{node[:prod_decider_count_threshold]} --comparison-operator LessThanThreshold  --dimensions '[{"Name":"InstanceID","Value":"#{node[:opsworks][:instance][:aws_instance_id]}"},{"Name":"Env","Value":"Prod"},{"Name":"App_name","Value":"Decider"}]' --evaluation-periods 1 --alarm-actions #{node[:arn_sns_details]} --unit Count
aws cloudwatch put-metric-alarm --alarm-name #{node[:prod_env]}_Worker_#{instance_count} --alarm-description "Alarm when Worker count lessthan #{node[:prod_worker_count_threshold]}" --metric-name  OnlineCount --namespace APP_Metrics --statistic Average --period 300 --threshold #{node[:prod_worker_count_threshold]} --comparison-operator LessThanThreshold  --dimensions '[{"Name":"InstanceID","Value":"#{node[:opsworks][:instance][:aws_instance_id]}"},{"Name":"Env","Value":"Prod"},{"Name":"App_name","Value":"Worker"}]' --evaluation-periods 1 --alarm-actions #{node[:arn_sns_details]} --unit Count
aws cloudwatch put-metric-alarm --alarm-name #{node[:prod_env]}_Disk_Space_#{instance_count} --alarm-description "Alarm when Disk space exceeds #{node[:prod_disk_space_threshold]} percent" --metric-name  Disk_Space --namespace APP_Metrics --statistic Average --period 300 --threshold #{node[:prod_disk_space_threshold]} --comparison-operator GreaterThanThreshold  --dimensions '[{"Name":"InstanceID","Value":"#{node[:opsworks][:instance][:aws_instance_id]}"},{"Name":"Env","Value":"Prod"},{"Name":"App_name","Value":"Disk_Space"}]' --evaluation-periods 1 --alarm-actions #{node[:arn_sns_details]} --unit Percent
EOH
end
end
instance_count=instance_count+1
end

else
Chef::Log.warn("Wrong layer selection")
end
