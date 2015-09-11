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
        id_count=`docker exec $id pm2 status all | awk '{print $5}' | wc -l`
        id_count=`expr $id_count - 2`
        i=4
        j=0
        while [ $i -le $id_count ]
        do
          docker exec $id pm2 stop $j &
	  i=`expr $i + 1`
          j=`expr $j + 1`
        done
     else
          echo "service is not running"
     fi
  done
  for id in $container_id
  do
    status=`docker inspect --format '{{ .State.Running }}' $id`
    if [ "$status" = "true" ]
    then
       id_count=`docker exec $id pm2 status all | awk '{print $11}' | wc -l`
       id_count=`expr $id_count - 2`
       i=4
       while [ $i -le $id_count ]
       do
         status=`docker exec $id pm2 status all | awk 'NR=='$i'{print $11}'`
         if [ $status = "stopped" ]
         then
           i=`expr $i + 1`
	 fi
	 sleep 5s
       done
     else
       echo "service is not running"
     fi
   done
fi
 EOH
end
end
