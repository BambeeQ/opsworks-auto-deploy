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
			# Set bucket and object name
			key = File.basename("pg_#{get_id}_#{time}.tar.gz")
			upload_status = s3.buckets["#{node[:backup_bucket_name]}"].objects[key].write(:file => "pg_#{get_id}_#{time}.tar.gz")
                        system("echo 'Postgres database backup upload completed \n https://s3.amazonaws.com/#{node[:backup_bucket_name]}/pg_#{get_id}_#{time}.tar.gz' | mail -s 'Postgres database backup upload completed' #{node[:mail_id]}")
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
