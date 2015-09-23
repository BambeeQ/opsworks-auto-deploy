require 'aws-sdk'
time = Time.now.strftime("%Y%m%d%H%M%S")
get_id = `id -u deploy`
get_id = get_id.delete!("\n")
dir_create = system("mkdir /tmp/mongo_#{get_id}_#{time}")
Dir.chdir("/tmp/")
backup_status = system("mongodump -h #{node[:mongodb_host]} -d #{node[:mongodb_prod_db]} -u #{node[:mongodb_prod_username]} -p #{node[:mongodb_prod_password]} -o /tmp/mongo_#{get_id}_#{time} ")
if  backup_status == true
    compression_status = system("tar cvf mongo_#{get_id}_#{time}.tar.gz mongo_#{get_id}_#{time}")
		if compression_status == true

			#Deploy code to release directory
			s3 = AWS::S3.new
			# Set bucket and object name
			key = File.basename("mongo_#{get_id}_#{time}.tar.gz")
			upload_status = s3.buckets["#{node[:backup_bucket_name]}"].objects[key].write(:file => "mongo_#{get_id}_#{time}.tar.gz")
                        system("echo 'Mongodb backup upload completed \n s3://#{node[:backup_bucket_name]}/mongo_#{get_id}_#{time}.tar.gz' | mail -s 'Mongodb backup upload completed' #{node[:mail_id]}")
                        system("rm -rf  mongo_#{get_id}_#{time}*")
		else
			Chef::Log.warn("Compresion failed")
		end
else
  Chef::Log.warn("Backup failed")
end
