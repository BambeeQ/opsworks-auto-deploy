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

bash "Drop_stage_postgres" do
  user "root"
  group "root"
  code <<-EOH
  export PGPASSWORD="#{node[:pg_admin_password]}"
  psql -h #{node[:pg_server_ip]} -d postgres -U #{node[:pg_admin_username]} -c "DROP DATABASE #{node[:pg_stage_db]};"
  psql -h #{node[:pg_server_ip]} -d postgres -U #{node[:pg_admin_username]} -c "CREATE DATABASE #{node[:pg_stage_db]};"
  mkdir -p #{node[:stage_prepare_dir]}
EOH
end

bash "backup_and_restore_pg_db" do
  user "root"
  group "root"
  cwd "#{node[:stage_prepare_dir]}"
  code <<-EOH
  export PGPASSWORD="#{node[:pg_admin_password]}"
  pg_dump -h #{node[:pg_server_ip]}  -Fc -o -U  #{node[:pg_admin_username]} #{node[:pg_prod_db]} > #{node[:pg_prod_db]}.sql
  EOH
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
