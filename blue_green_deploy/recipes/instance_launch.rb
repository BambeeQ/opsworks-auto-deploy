require 'aws-sdk'

frontend_layer_id = node[:opsworks][:layers]["#{node[:submodules][:frontend][:layer]}"][:id]
backend_layer_id = node[:opsworks][:layers]["#{node[:submodules][:backend][:layer]}"][:id]
frontend_no_of_instance = node[:opsworks][:layers]["#{node[:submodules][:frontend][:layer]}"][:instances].count
backend_no_of_instance = node[:opsworks][:layers]["#{node[:submodules][:backend][:layer]}"][:instances].count
opsworks = AWS::OpsWorks::Client.new

if frontend_no_of_instance == 0 && backend_no_of_instance == 0
frontend_status = []
backend_status = []
node[:submodules][:frontend][:no_of_instance].times do |index|
Chef::Log.warn(index)
frontend = opsworks.create_instance({
  stack_id: node[:opsworks][:stack][:id],
  layer_ids: ["#{frontend_layer_id}"],
  instance_type: "#{node[:submodules][:frontend][:instance_type]}",
  os: "Custom",
  ami_id: node[:submodules][:frontend][:ami_id],
})


opsworks.start_instance({
  instance_id: frontend.instance_id,
})
frontend_status.push(frontend.instance_id)
end

node[:submodules][:backend][:no_of_instance].times do |index|

backend = opsworks.create_instance({
  stack_id: node[:opsworks][:stack][:id],
  layer_ids: ["#{backend_layer_id}"],
  instance_type: node[:submodules][:backend][:instance_type],
  os: "Custom",
  ami_id: node[:submodules][:backend][:ami_id],
})

opsworks.start_instance({
  instance_id: backend.instance_id,
})
backend_status.push(backend.instance_id)
end

node[:submodules][:frontend][:no_of_instance].times do |index|
start_status = opsworks.describe_instances({
  instance_ids: [frontend_status[index]],
})
taskdone=0
instance_status = start_status.instances[0].status
while  taskdone != 1 do
         instance_status = start_status.instances[0].status
         if "#{instance_status}" == "online"
           taskdone=1
         else
           system("sleep 5s")
           Chef::Log.warn(instance_status)
	   start_status = opsworks.describe_instances({
  instance_ids: [frontend_status[index]],
})
         end
end
end

node[:submodules][:backend][:no_of_instance].times do |index|
start_status = opsworks.describe_instances({
  instance_ids: [backend_status[index]],
})

taskdone=0
instance_status = start_status.instances[0].status
while  taskdone != 1 do
         instance_status = start_status.instances[0].status
         if "#{instance_status}" == "online"
           taskdone=1
         else
           system("sleep 5s")
           Chef::Log.warn(instance_status)
           start_status = opsworks.describe_instances({
  instance_ids: [backend_status[index]],
})

         end
end
end
end
