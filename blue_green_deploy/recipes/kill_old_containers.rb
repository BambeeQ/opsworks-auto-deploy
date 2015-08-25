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
        sleep 5m
        docker ps -aq | xargs -n 1 -t docker stop
	docker ps -aq | xargs -n 1 -t docker rm
	fi
  EOH
end
end
