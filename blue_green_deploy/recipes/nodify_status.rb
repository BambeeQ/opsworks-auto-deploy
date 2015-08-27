bash "deploy_notify" do
user "root"
group "root"
code <<-EOH
aws --region "#{node[:opsworks][:instance][:region]}" sns publish \
--topic-arn #{node[:sns][:failover_topic]} \
--subject "#{node[:sns][:subject]}" \
--message "{action: "#{node[:sns][:action]}", command: "#{node[:sns][:command]}"}"

EOH
end
