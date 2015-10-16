require 'aws-sdk'
if node[:opsworks][:instance][:layers][0].to_s == "#{node[:backup_layer]}"
time = Time.now.strftime("%Y%m%d%H%M%S")
get_id = `id -u deploy`
get_id = get_id.delete!("\n")
dir_create = system("mkdir -p /data/pg_#{get_id}_#{time}")
Dir.chdir("/data/pg_#{get_id}_#{time}")
backup_status= system("export PGPASSWORD=#{node[:pg_prod_password]} && pg_dump -h  #{node[:pg_server_ip]}  -Fc -o -U #{node[:pg_prod_username]} -T -d #{node[:pg_prod_db]} > #{node[:pg_prod_db]}.sql")

if  backup_status == true
Dir.chdir("/data/")
    compression_status = system("tar cvf pg_#{get_id}_#{time}.tar.gz pg_#{get_id}_#{time}")
		if compression_status == true
			#Deploy code to release directory
			s3 = AWS::S3.new
                        upload_status = system("aws --profile=backup s3 cp /data/pg_#{get_id}_#{time}.tar.gz s3://#{node[:backup_bucket_name]}/ --grants read=uri=http://acs.amazonaws.com/groups/global/AuthenticatedUsers")
                      
			 if upload_status == true
                              object = s3.buckets["#{node[:backup_bucket_name]}"].objects["pg_#{get_id}_#{time}.tar.gz"]
                              get_url = object.url_for(:read, { :expires => 86400, :secure => true }).to_s
			       system("echo 'Postgres database backup upload completed \n\n User Authentication URL: https://s3.amazonaws.com/#{node[:backup_bucket_name]}/pg_#{get_id}_#{time}.tar.gz \n\n 24hours session url: \n #{get_url}' | mail -s 'Postgres database backup upload completed' #{node[:mail_id]}")
                        else
                           system("echo 'Postgres database backup upload failed \n' | mail -s 'Postgres database backup upload failed' #{node[:mail_id]}")
                        end

                        system("rm -rf  pg_#{get_id}_#{time}*")
		else
			Chef::Log.warn("Compresion failed")
      system("echo 'Postgres database backup failed \n' | mail -s 'Postgres database backup failed' #{node[:mail_id]}")

		end
else
  Chef::Log.warn("Backup failed")
  system("echo 'Postgres database backup failed \n' | mail -s 'Postgres database backup failed' #{node[:mail_id]}")
end
else
Chef::Log.warn("This is not backup layer")
end
