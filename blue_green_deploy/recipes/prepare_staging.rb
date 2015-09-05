require 'aws-sdk'

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


#checking frontend layer
if  node[:opsworks][:layers]["#{node[:submodules][:frontend][:layer]}"][:instances].first[0] == node["opsworks"]["instance"]["hostname"]

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


bash "Drop_stage_mongodb" do
  user "root"
  group "root"
  code <<-EOH
  mongo #{node[:drop_mongodb_url]} -u #{node[:mongodb_admin_username]} -p #{node[:mongodb_admin_password]} --authenticationDatabase admin <<EOF
  db.dropDatabase()
  EOF
EOH
end


        #Deploy code to release directory
        s3 = AWS::S3.new
        # Set bucket and object name
        obj = s3.buckets["#{node[:submodules][:frontend][:bucket_name]}"].objects["#{node[:submodules][:frontend][:file_name]}"]
        # Read content to variable
        if !node[:submodules][:frontend][:version_id].empty?
        file_content = obj.read(:version_id=>"#{node[:submodules][:frontend][:version_id]}")
        else
        file_content = obj.read
        end
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


  script "run_app_container" do
    interpreter "bash"
    user "root"
    code <<-EOH
      docker run -d  -h #{node["opsworks"]["instance"]["hostname"][9,20]}  -v /var/www/frontend/current/:/var/www -p 80:3000 --name=app0  #{node[:submodules][:frontend_image]} pm2 start -x /var/www/start.sh --watch --no-daemon
      if [ $? = 1 ]
      then
      docker restart app0
      fi

    EOH
  end


elsif  node[:opsworks][:layers]["#{node[:submodules][:backend][:layer]}"][:instances].first[0] == node["opsworks"]["instance"]["hostname"]
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


bash "Drop_stage_postgres" do
user "root"
group "root"
code <<-EOH
export PGPASSWORD="#{node[:pg_admin_password]}"
psql -h #{node[:pg_server_ip]} -d postgres -U #{node[:pg_admin_username]} -c "DROP DATABASE #{node[:pg_stage_db]};"
psql -h #{node[:pg_server_ip]} -d postgres -U #{node[:pg_admin_username]} -c "CREATE DATABASE #{node[:pg_stage_db]};"
EOH
end



execute 'Pg_backup' do
  cwd "/var/www/backend/release/#{time}"
  command "pg_dump -h  #{node[:pg_server_ip]}  -Fc -o -U #{node[:pg_prod_username]} -T -d #{node[:pg_prod_db]} > #{node[:pg_prod_db]}.sql"
  environment 'PGPASSWORD' => "#{node[:pg_prod_password]}"
  user "root"
  action :run
end

execute 'Pg_Restore' do
  cwd "/var/www/backend/release/#{time}"
  command "pg_restore -h #{node[:pg_server_ip]}  -U #{node[:pg_stage_username]} --no-owner --no-privileges --no-tablespaces -n public -d #{node[:pg_stage_db]} < #{node[:pg_prod_db]}.sql"
  environment 'PGPASSWORD' => "#{node[:pg_stage_password]}"
  user "root"
  action :run
end




template "/var/www/backend/release/#{time}/start.sh" do
    source "start.erb"
    user "root"
    group "root"
    mode 777
 variables(

    :json => node[:submodules][:backend][:stage_json],
    :cron_json =>  node[:submodules][:backend][:stage_cron_json],
    :backend_layer => node[:opsworks][:layers]["#{node[:submodules][:backend][:layer]}"][:instances].first[0],
)
  end

s3 = AWS::S3.new
# Set bucket and object name
obj = s3.buckets["#{node[:submodules][:backend][:bucket_name]}"].objects["#{node[:submodules][:backend][:file_name]}"]
# Read content to variable
if !node[:submodules][:backend][:version_id].empty?
file_content = obj.read(:version_id=>"#{node[:submodules][:backend][:version_id]}")
else
file_content = obj.read
end
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
  npm install  knex liftoff interpret commander minimist v8flags chalk tildify
EOH
end

link "/var/www/backend/current" do
  action :delete
  only_if "test -L /var/www/backend/current"
end


link "/var/www/backend/current" do
  to "/var/www/backend/release/#{time}"
end

  script "run_app_container" do
    interpreter "bash"
    user "root"
    code <<-EOH
      docker run -d -h #{node["opsworks"]["instance"]["hostname"][9,20]}  -p 3001:3000 --name=app1 -v /var/www/backend/current:/var/www  #{node[:submodules][:backend_image]} /var/www/start.sh
      docker exec app1 ./swf/core/bin/knex migrate:latest --env #{node[:db_migration_env]}
      if [ $? = 1 ]
      then
      docker restart app1
      fi
      docker exec app1 ./swf/bin/cleanup --settings #{node[:cleanup_json]} --domain #{node[:cleanup_domain]}
    EOH
  end

  if node[:opsworks][:layers]["#{node[:submodules][:backend][:layer]}"][:instances].first[0] == node["opsworks"]["instance"]["hostname"]
    template "/var/www/backend/release/#{time}/cron.sh" do
        source "cron.erb"
        user "root"
        group "root"
        mode 777
     variables(
        :cron_json =>  node[:submodules][:backend][:stage_cron_json],
        :backend_layer => node[:opsworks][:layers]["#{node[:submodules][:backend][:layer]}"][:instances].first[0],
    )
      end
      script "run_cron_json" do
        interpreter "bash"
        user "root"
        code <<-EOH
          docker exec app1 sh cron.sh &
        EOH
      end
  end


else
Chef::Log.warn("Wrong layer selection")
end
