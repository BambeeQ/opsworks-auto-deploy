require 'aws-sdk'

frontend_layer_id = node[:opsworks][:layers]["#{node[:submodules][:frontend][:layer]}"][:id]
backend_layer_id = node[:opsworks][:layers]["#{node[:submodules][:backend][:layer]}"][:id]
frontend_no_of_instance = node[:opsworks][:layers]["#{node[:submodules][:frontend][:layer]}"][:instances].count
backend_no_of_instance = node[:opsworks][:layers]["#{node[:submodules][:backend][:layer]}"][:instances].count

opsworks = AWS::OpsWorks::Client.new
if "#{node[:shutdown_instance]}" == 'true'
if frontend_no_of_instance != 0 && backend_no_of_instance != 0
frontend = opsworks.describe_instances({
  layer_id: "#{frontend_layer_id}",
})

frontend.instances.each do |value|
status = value.instance_id
opsworks.stop_instance({
  instance_id: "#{status}",
})
end

backend = opsworks.describe_instances({
  layer_id: "#{backend_layer_id}",
})

backend.instances.each do |value|
status = value.instance_id
opsworks.stop_instance({
  instance_id: "#{status}",
})
end


frontend.instances.each do |value|
frontend = opsworks.describe_instances({
  instance_ids: [value.instance_id],
})

taskdone=0
instance_status = frontend.instances[0].status
while  taskdone != 1 do
         instance_status = frontend.instances[0].status
         if "#{instance_status}" == "stopped"
           taskdone=1
          opsworks.delete_instance({
  			  instance_id: value.instance_id,
			  delete_volumes: true,
			})
         else
           system("sleep 5s")
#           Chef::Log.warn(instance_status)
	   frontend = opsworks.describe_instances({
  instance_ids: [value.instance_id],
})

         end
end
end


backend.instances.each do |value|
backend = opsworks.describe_instances({
  instance_ids: [value.instance_id],
})

taskdone=0
instance_status = backend.instances[0].status
while  taskdone != 1 do
         instance_status = backend.instances[0].status
         if "#{instance_status}" == "stopped"
           taskdone=1
          opsworks.delete_instance({
  			  instance_id: value.instance_id,
			  delete_volumes: true,
			})
         else
           system("sleep 5s")
#           Chef::Log.warn(instance_status)
	   backend = opsworks.describe_instances({
  instance_ids: [value.instance_id],
})

         end
end
end
end
end
