# Pull latest images
if node[:env] == 'staging'

if node[:opsworks][:instance][:layers][0].to_s == "#{node[:submodules][:frontend][:layer]}"
  template "#{node[:submodules][:frontend][:dir]}/Dockerfile" do
    cookbook "submodules"
    source "Dockerfile.erb"
    user "root"
    group "root"
  end

  template "#{node[:submodules][:frontend][:dir]}/supervisord.conf" do
    source "supervisord.conf.erb"
    user "root"
    group "root"
  end

  template "/var/www/#{node[:submodules][:frontend][:release]}/start.sh" do
    source "start.erb"
    user "root"
    group "root"
    mode 777
  end

  script "Build_docker_image" do
    interpreter "bash"
    user "root"
    cwd "#{node[:submodules][:frontend][:dir]}"
    code <<-EOH
      docker build -t #{node[:submodules][:docker_image_name]} .
    EOH
  end
elsif node[:opsworks][:instance][:layers][0].to_s == "#{node[:submodules][:backend][:layer]}"
then
  template "#{node[:submodules][:backend][:dir]}/Dockerfile" do
    source "Dockerfile_be.erb"
    user "root"
    group "root"
  end

  template "#{node[:submodules][:backend][:dir]}/supervisord.conf" do
    source "supervisord.conf.erb"
    user "root"
    group "root"
  end

  template "/var/www/#{node[:submodules][:backend][:release]}/start.sh" do
    source "start.erb"
    user "root"
    group "root"
    mode 777
  end

  script "Build_docker_image" do
    interpreter "bash"
    user "root"
    cwd "#{node[:submodules][:backend][:dir]}"
    code <<-EOH
      docker build -t #{node[:submodules][:docker_image_name]} .
    EOH
  end
else
Chef::Log.warn("Wrong layer selection")
end
end
