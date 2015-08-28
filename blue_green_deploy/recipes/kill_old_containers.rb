if node[:opsworks][:instance][:layers][0].to_s == "#{node[:submodules][:frontend][:layer]}" ||  node[:opsworks][:instance][:layers][0].to_s == "#{node[:submodules][:backend][:layer]}"

script "kill_all_containers" do
  interpreter "bash"
  user "root"
  code <<-EOH
	count=`docker ps -aq | wc -l`
	if [ $count -eq 0 ]
	then
	echo "no continers to remove"
	else
        docker ps -aq | xargs -I{} docker exec {} pm2 sendSignal SIGQUIT all
        docker ps -aq | xargs -I{} docker exec {} pm2 stop all 
	fi
  EOH
end
end
