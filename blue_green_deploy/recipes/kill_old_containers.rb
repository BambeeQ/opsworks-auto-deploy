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
     container_id=`docker ps -aq`
     for id in $container_id
     do
       status=`docker inspect --format '{{ .State.Running }}' $id`
       if [ "$status" = "true" ]
       then
          docker exec $id pm2 sendSignal SIGQUIT all
          docker exec $id pm2 stop all
       else
          echo "service is not running"
       fi
     done
	fi
  EOH
end
end
