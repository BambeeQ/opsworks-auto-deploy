service "nginx" do
  supports :restart => true, :status => true, :reload => true
  action :nothing # only define so that it can be restarted if the config changed
end


template "/etc/nginx/#{node[:stage_domain_name]}.upstream" do
  cookbook "nginx"
  source "load_balance_upstream.cfg.erb"
  owner "root"
  group "root"
  mode 0644
  variables(
    :instance_value => node[:opsworks][:layers]["#{node[:layer]}"][:instances],
    :layers => node[:opsworks][:layers],
    :layers_blue => node[:opsworks][:layers]["#{node[:layer]}"],
    :layers_blue_count => node[:opsworks][:layers]["#{node[:layer]}"][:instances].count,
    :container_count => node[:submodules][:frontend][:instance_count],
  )
end

template "/etc/nginx/sites-available/#{node[:stage_domain_name]}.conf" do
  cookbook "nginx"
  source "load_balance.cfg.erb"
  owner "root"
  group "root"
  mode 0644
  variables(
    :server_name => node[:stage_domain_name],
  )

  notifies :reload, "service[nginx]"
end

bash "production upstream files" do
  user 'root'
  group 'root'
  code <<-EOH
  touch /etc/nginx/#{node[:prod_domain_name]}.upstream
  EOH
not_if { ::File.exists? "/etc/nginx/#{node[:prod_domain_name]}.upstream" }
end

link "/etc/nginx/sites-enabled/default" do
  action :delete
  only_if "test -L /etc/nginx/sites-enabled/default"
end

link "/etc/nginx/sites-enabled/#{node[:stage_domain_name]}.conf" do
  to "/etc/nginx/sites-available/#{node[:stage_domain_name]}.conf"
end

execute "echo 'nginx reload'" do
  notifies :reload, "service[nginx]"
end

execute "echo 'checking if nginx is not running - if so start it'" do
  not_if "pgrep nginx"
  notifies :start, "service[nginx]"
end
