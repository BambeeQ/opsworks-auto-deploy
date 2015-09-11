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
        id_count=`docker exec $id pm2 status all | awk -F '│' '{print $6}'|grep -vE '(^$|status)'|wc -l`
        i=0
        while [ $i -lt $id_count ]
        do
          docker exec $id pm2 stop $i &
          i=`expr $i + 1`
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
       id_count=`docker exec $id pm2 status all | awk -F '│' '{print $6}'|grep -vE '(^$|status)'|wc -l`
       taskdone=0
       while [ $taskdone -ne 1 ]
       do
         stopped_count=`docker exec $id pm2 status all | awk -F '│' '{print $6}'|grep -vE '(^$|status)'|grep 'stopped' |wc -l`
         if [ $stopped_count -eq $id_count ]
         then
           taskdone=1
         else
           sleep 5s
         fi
       done
     else
       echo "service is not running"
     fi

   done
fi
 EOH
end
end
