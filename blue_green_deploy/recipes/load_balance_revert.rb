service "nginx" do
  supports :restart => true, :status => true, :reload => true
  action :nothing # only define so that it can be restarted if the config changed
end

file "/etc/nginx/#{node[:prod_domain_name]}.upstream" do
  owner 'root'
  group 'root'
  mode 0755
  content ::File.open("/etc/nginx/#{node[:prod_domain_name]}.upstream.bk").read
  action :create
  backup 1
end


execute "echo 'nginx reload'" do
  notifies :reload, "service[nginx]"
end


execute "echo 'checking if nginx is not running - if so start it'" do
  not_if "pgrep nginx"
  notifies :start, "service[nginx]"
end
