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
mkdir -p #{node[:stage_prepare_dir]}/backend
mkdir -p #{node[:stage_prepare_dir]}/frontend
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
  command "pg_restore -h #{node[:pg_server_ip]}  -U #{node[:pg_admin_username]} -n public -d #{node[:pg_stage_db]} < #{node[:pg_prod_db]}.sql"
  environment 'PGPASSWORD' => "#{node[:pg_admin_password]}"
  user "root"
  action :run
end

script "kill_all_containers" do
  interpreter "bash"
  user "root"
  code <<-EOH
        count=`docker ps -aq | wc -l`
        if [ $count -eq 0 ]
        then
        echo "no continers to remove"
        else
        docker ps -aq | xargs -n 1 -t docker stop
        docker ps -aq | xargs -n 1 -t docker rm
        fi
  EOH
end


#Deploy code to release directory
s3 = AWS::S3.new
 # Set bucket and object name
obj = s3.buckets["#{node[:submodules][:frontend][:bucket_name]}"].objects["#{node[:submodules][:frontend][:file_name]}"]
# Read content to variable
file_content = obj.read
# Write content to file
        file "#{node[:stage_prepare_dir]}/frontend/#{node[:submodules][:frontend][:file_name]}" do
        owner 'root'
          group 'root'
          content file_content
          action :create
        end

	template "#{node[:stage_prepare_dir]}/frontend/start.sh" do
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
     cwd "#{node[:stage_prepare_dir]}/frontend"
     code <<-EOH
     tar -xvf #{node[:submodules][:frontend][:file_name]}
     EOH
end



template "#{node[:stage_prepare_dir]}/backend/start.sh" do
    source "start.erb"
    user "root"
    group "root"
    mode 777
 variables(

    :json => node[:submodules][:backend][:stage_json],
)
  end

script "run_app_container" do
    interpreter "bash"
    user "root"
    code <<-EOH
      docker run -d -p 3000:3000 --name=app0 -v #{node[:stage_prepare_dir]}/frontend/:/var/www  #{node[:submodules][:my_docker_image]}
    EOH
  end

s3 = AWS::S3.new
# Set bucket and object name
obj = s3.buckets["#{node[:submodules][:backend][:bucket_name]}"].objects["#{node[:submodules][:backend][:file_name]}"]
# Read content to variable
file_content = obj.read
# Write content to file
file "#{node[:stage_prepare_dir]}/backend/#{node[:submodules][:backend][:file_name]}" do
  owner 'root'
  group 'root'
  content file_content
  action :create
end

bash "Backend_updates" do
     user "root"
     group "root"
     cwd "#{node[:stage_prepare_dir]}/backend"
     code <<-EOH
     tar -xvf #{node[:submodules][:backend][:file_name]}
     npm install  knex liftoff coffee-script interpret commander minimist v8flags chalk tildify
     EOH
end

script "run_app_container" do
    interpreter "bash"
    user "root"
    code <<-EOH
      docker run -d -p 3001:3000 --name=app1 -v #{node[:stage_prepare_dir]}/backend/:/var/www  #{node[:submodules][:my_docker_image]}
      docker exec app1 ./swf/core/bin/knex migrate:latest --env #{node[:db_migration_env]}
    EOH
  end

script "kill_all_containers" do
  interpreter "bash"
  user "root"
  code <<-EOH
        count=`docker ps -aq | wc -l`
        if [ $count -eq 0 ]
        then
        echo "no continers to remove"
        else
        docker ps -aq | xargs -n 1 -t docker stop
        docker ps -aq | xargs -n 1 -t docker rm
        fi
  EOH
end

else
Chef::Log.warn("Wrong layer selection")
end
