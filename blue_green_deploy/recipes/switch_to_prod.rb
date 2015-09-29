service "nginx" do
  supports :restart => true, :status => true, :reload => true
  action :nothing # only define so that it can be restarted if the config changed
end

#rest = Chef::REST.new("#{node[:prod_ghostscript_url]}")
#nodes = rest.get_rest("#{node[:prod_ghostscript_url]}")
#data = nodes['data']
#def checkPassing(data)
# data.each do |value|
#         if value['passing'] == false
#         return false
#      end
#  end
#  return true
#end
#passing = checkPassing(data)

#if passing == true
#Chef::Log.info("Success")

file "/etc/nginx/sites-available/#{node[:prod_domain_name]}.conf" do
  owner 'root'
  group 'root'
  mode 0755
  content ::File.open("/etc/nginx/sites-available/#{node[:stage_domain_name]}.conf").read
  action :create
  backup 1
end

file "/etc/nginx/#{node[:prod_domain_name]}.upstream.bk" do
  owner 'root'
  group 'root'
  mode 0755
  content ::File.open("/etc/nginx/#{node[:prod_domain_name]}.upstream").read
  action :create
  backup 1
end


file "/etc/nginx/#{node[:prod_domain_name]}.upstream" do
  owner 'root'
  group 'root'
  mode 0755
  content ::File.open("/etc/nginx/#{node[:stage_domain_name]}.upstream").read
  action :create
  backup 1
end


bash "server_name updates" do
  user 'root'
  group 'root'
  code <<-EOH
  sed -i "s/#{node[:stage_domain_name]}/#{node[:prod_domain_name]}/gi" /etc/nginx/sites-available/#{node[:prod_domain_name]}.conf
  sed -i "s/#{node[:stage_upstream_cluster]}/#{node[:prod_upstream_cluster]}/gi" /etc/nginx/sites-available/#{node[:prod_domain_name]}.conf
  sed -i "s/#{node[:stage_upstream_cluster]}/#{node[:prod_upstream_cluster]}/gi" /etc/nginx/#{node[:prod_domain_name]}.upstream
  echo "" > /etc/nginx/#{node[:stage_domain_name]}.upstream
  EOH
end

link "/etc/nginx/sites-enabled/#{node[:prod_domain_name]}.conf" do
  to "/etc/nginx/sites-available/#{node[:prod_domain_name]}.conf"
end


link "/etc/nginx/sites-enabled/#{node[:stage_domain_name]}.conf" do
  action :delete
  only_if "test -L /etc/nginx/sites-enabled/#{node[:stage_domain_name]}.conf"
end

execute "echo 'nginx reload'" do
  notifies :reload, "service[nginx]"
end


execute "echo 'checking if nginx is not running - if so start it'" do
  not_if "pgrep nginx"
  notifies :start, "service[nginx]"
end

#else
#Chef::Application.fatal!("failed")
#end
