require 'aws-sdk'
if  node[:opsworks][:layers]["#{node[:layer]}"][:instances].first[0].to_s == node["opsworks"]["instance"]["hostname"]

bash "Drop_stage_mongodb" do
  user "root"
  group "root"
  code <<-EOH
  mongo #{node[:drop_mongodb_url]} -u #{node[:mongodb_admin_username]} -p #{node[:mongodb_admin_password]} --authenticationDatabase admin <<EOF
  db.dropDatabase()
  EOF
EOH
end


execute 'Pg_backup' do
  cwd "#{node[:stage_prepare_dir]}"
  command "pg_dump -h  #{node[:pg_server_ip]}  -Fc -o -U #{node[:pg_admin_username]} -T -d #{node[:pg_prod_db]} > #{node[:pg_prod_db]}.sql"
  environment 'PGPASSWORD' => "#{node[:pg_admin_password]}"
  user "root"
  action :run
end


execute 'Pg_Restore' do
  cwd "#{node[:stage_prepare_dir]}"
<<<<<<< HEAD
  command "pg_restore -h #{node[:pg_server_ip]}  -U #{node[:pg_admin_username]} -n public -d #{node[:pg_stage_db]} < #{node[:pg_prod_db]}.sql"
  environment 'PGPASSWORD' => "#{node[:pg_admin_password]}"
  user "root"
  action :run
=======
  code <<-EOH
  export PGPASSWORD="#{node[:pg_admin_password]}"
  pg_dump -h #{node[:pg_server_ip]}  -Fc -o -U  #{node[:pg_admin_username]} #{node[:pg_prod_db]} > #{node[:pg_prod_db]}.sql
  EOH
>>>>>>> 083c1d07214a79b9ef7e8c22fc39f8f6de83487e
end



#Deploy code to release directory
s3 = AWS::S3.new
 # Set bucket and object name
obj = s3.buckets["#{node[:submodules][:frontend][:bucket_name]}"].objects["#{node[:submodules][:frontend][:file_name]}"]
# Read content to variable
file_content = obj.read
# Write content to file
        file "#{node[:stage_prepare_dir]}/#{node[:submodules][:frontend][:file_name]}" do
        owner 'root'
          group 'root'
          content file_content
          action :create
        end

	template "#{node[:stage_prepare_dir]}/start.sh" do
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


bash "Frontend_updates" do
     user "root"
     group "root"
     cwd "#{node[:stage_prepare_dir]}"
     code <<-EOH
     tar -xvf #{node[:submodules][:frontend][:file_name]}
     rm -rf #{node[:stage_prepare_dir]}/#{node[:submodules][:frontend][:file_name]}
     sh -x start.sh &
     sleep 15s
     kill -9 `pgrep -f start.sh`
     rm  -rf #{node[:stage_prepare_dir]}/*
     EOH
end



template "#{node[:stage_prepare_dir]}/start.sh" do
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
file "#{node[:stage_prepare_dir]}/#{node[:submodules][:backend][:file_name]}" do
  owner 'root'
  group 'root'
  content file_content
  action :create
end

bash "Backend_updates" do
     user "root"
     group "root"
     cwd "#{node[:stage_prepare_dir]}"
     code <<-EOH
     tar -xvf #{node[:submodules][:backend][:file_name]}
     rm -rf #{node[:stage_prepare_dir]}/#{node[:submodules][:backend][:file_name]}
     sh -x start.sh &
     ./swf/core/bin/knex migrate:latest --env #{node[:db_migration_env]}
     sleep 15s
     kill -9 `pgrep -f start.sh`
     rm  -rf #{node[:stage_prepare_dir]}/*
     EOH
end
else
Chef::Log.warn("Wrong layer selection")
end
