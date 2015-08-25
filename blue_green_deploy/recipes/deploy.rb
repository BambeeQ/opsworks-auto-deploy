require 'aws-sdk'
#checking frontend layer        
if node[:opsworks][:instance][:layers][0].to_s == "#{node[:submodules][:frontend][:layer]}"

		%w[ /var/www/frontend  /var/www/frontend/release ].each do |path|
  		directory path do
    		  owner 'root'
    		  group 'root'
    		  mode '0755'
  		end
	        end
	
	#Getting time
	time = Time.now.strftime("%Y%m%d%H%M%S")
        #create release directory with timestamp
	directory "/var/www/frontend/release/#{time}" do
  	  owner 'root'
  	  group 'root'
  	  mode '0755'
  	  action :create
	end

	#Deploy code to release directory
	s3 = AWS::S3.new
	# Set bucket and object name
	obj = s3.buckets["#{node[:submodules][:frontend][:bucket_name]}"].objects["#{node[:submodules][:frontend][:file_name]}"]
	# Read content to variable
	file_content = obj.read
	# Write content to file
	file "/var/www/frontend/release/#{time}/#{node[:submodules][:frontend][:file_name]}" do
  	owner 'root'
	  group 'root'
	  content file_content
	  action :create
	end

	#Clear old release
	bash "Clear old release" do
	  user "root"
	  cwd "/var/www/frontend/release/"
	  code <<-EOT
	  (ls -t|head -n 5;ls)|sort|uniq -u|xargs rm -rf
	  EOT
	end

	#Extract deploy code
	bash "release_updates" do
	  user "root"
	  group "root"
	  cwd "/var/www/frontend/release/#{time}"
	  code <<-EOH
	  tar -xvf #{node[:submodules][:frontend][:file_name]}
          rm -rf /var/www/frontend/release/#{time}/#{node[:submodules][:frontend][:file_name]}
          EOH
	end
        #Create startup script with environment variables
	template "/var/www/frontend/release/#{time}/start.sh" do
	    source "start.erb"
	    user "root"
	    group "root"
	    mode 777
	variables(
	    :mongo_url => node[:submodules][:frontend][:stage_mongo_url] ,
	    :root_url => node[:submodules][:frontend][:stage_root_url],
	    :mail_url => node[:submodules][:frontend][:stage_mail_url],
	    :port => node[:submodules][:frontend][:internal_port],
	    :meteor_setting_json => node[:submodules][:frontend][:stage_meteor_setting_json],
	  )

	end



link "/var/www/frontend/current" do
  action :delete
  only_if "test -L /var/www/frontend/current"
end

link "/var/www/frontend/current" do
  to "/var/www/frontend/release/#{time}"
end


node[:submodules][:frontend][:instance_count].times do |index|
  script "run_app_#{index}_container" do
    interpreter "bash"
    user "root"
    code <<-EOH
      docker run -d  -h "#{node[:submodules][:frontend][:host_name]}"  -v /var/www/frontend/current/:/var/www -p 8#{index}:3000 --name=app#{index}  #{node[:submodules][:my_docker_image]} 
    EOH
  end
end


elsif node[:opsworks][:instance][:layers][0].to_s == "#{node[:submodules][:backend][:layer]}"
then

%w[ /var/www/backend  /var/www/backend/release ].each do |path|
  directory path do
    owner 'root'
    group 'root'
    mode '0755'
  end
end

time = Time.now.strftime("%Y%m%d%H%M%S")
directory "/var/www/backend/release/#{time}" do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end



template "/var/www/backend/release/#{time}/start.sh" do
    source "start.erb"
    user "root"
    group "root"
    mode 777
 variables(

    :json => node[:submodules][:backend][:stage_json],
)
  end




s3 = AWS::S3.new
# Set bucket and object name
obj = s3.buckets["#{node[:submodules][:backend][:bucket_name]}"].objects["#{node[:submodules][:backend][:file_name]}"]
# Read content to variable
file_content = obj.read
# Write content to file
file "/var/www/backend/release/#{time}/#{node[:submodules][:backend][:file_name]}" do
  owner 'root'
  group 'root'
  content file_content
  action :create
end

bash "Clear old release" do
  user "root"
  cwd "/var/www/backend/release"
  code <<-EOT
  (ls -t|head -n 5;ls)|sort|uniq -u|xargs rm -rf
  EOT
end


bash "release_updates" do
  user "root"
  group "root"
  cwd "/var/www/backend/release/#{time}"
  code <<-EOH
  tar -xvzf #{node[:submodules][:backend][:file_name]}
  rm -rf /var/www/backend/release/#{time}/#{node[:submodules][:backend][:file_name]}
EOH
end

link "/var/www/backend/current" do
  action :delete
  only_if "test -L /var/www/backend/current"
end

link "/var/www/backend/current" do
  to "/var/www/backend/release/#{time}"
end

node[:submodules][:backend][:instance_count].times do |index|
  script "run_app_#{index}_container" do
    interpreter "bash"
    user "root"
    code <<-EOH
      docker run -d -p 300#{index}:3000 --name=app#{index} -v /var/www/backend/current:/var/www  #{node[:submodules][:my_docker_image]} 
    EOH
  end
end
  
else
Chef::Log.warn("Wrong layer selection")
end

