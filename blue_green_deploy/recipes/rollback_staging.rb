if node[:opsworks][:instance][:layers][0].to_s == "#{node[:submodules][:frontend][:layer]}"
	template "/var/www/frontend/current/start.sh" do
            source "start.erb"
            user "root"
            group "root"
            mode 777
            variables(
            :mongo_url => node[:submodules][:frontend][:stage_mongo_url] ,
            :root_url => node[:submodules][:frontend][:stage_root_url],
            :mail_url => node[:submodules][:frontend][:stage_mail_url],
            :port => node[:submodules][:frontend][:internal_port],
            :meteor_setting_json => node[:submodules][:frontend][:stage_meteor_setting_json],
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

else if node[:opsworks][:instance][:layers][0].to_s == "#{node[:submodules][:backend][:layer]}"
then
        template "/var/www/frontend/release/current/start.sh" do
            source "start.erb"
            user "root"
            group "root"
            mode 777
            variables(
              :json => node[:submodules][:backend][:stage_json],
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

else
Chef::Log.warn("Wrong layer selection")
end
