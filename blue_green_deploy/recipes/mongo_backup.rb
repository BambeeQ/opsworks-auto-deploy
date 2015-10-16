require 'aws-sdk'
if node[:opsworks][:instance][:layers][0].to_s == "#{node[:backup_layer]}"
time = Time.now.strftime("%Y%m%d%H%M%S")
get_id = `id -u deploy`
get_id = get_id.delete!("\n")
dir_create = system("mkdir -p /data/mongo_#{get_id}_#{time}")
Dir.chdir("/data/")
backup_status = system("mongodump -h #{node[:mongodb_host]} -d #{node[:mongodb_prod_db]} -u #{node[:mongodb_prod_username]} -p #{node[:mongodb_prod_password]} -o /data/mongo_#{get_id}_#{time} ")
if  backup_status == true
    compression_status = system("tar cvf mongo_#{get_id}_#{time}.tar.gz mongo_#{get_id}_#{time}")
		if compression_status == true

			#Deploy code to release directory
			s3 = AWS::S3.new
                         upload_status = system("aws --profile=backup s3 cp /data/mongo_#{get_id}_#{time}.tar.gz s3://#{node[:backup_bucket_name]}/ --grants read=uri=http://acs.amazonaws.com/groups/global/AuthenticatedUsers")
                         
			if upload_status == true
      			      object = s3.buckets["#{node[:backup_bucket_name]}"].objects["mongo_#{get_id}_#{time}.tar.gz"]
			      get_url = object.url_for(:read, { :expires => 86400, :secure => true }).to_s
			      system("echo 'Mongodb backup upload completed \n\n User Authentication URL: \n https://s3.amazonaws.com/#{node[:backup_bucket_name]}/mongo_#{get_id}_#{time}.tar.gz \n\n 24hours session url: \n #{get_url}' | mail -s 'Mongodb backup upload completed' #{node[:mail_id]}")
                        else
                           system("echo 'Mongodb database backup upload failed \n' | mail -s 'Mongodb database backup upload failed' #{node[:mail_id]}")
                        end

      system("rm -rf  mongo_#{get_id}_#{time}*")
		else
			Chef::Log.warn("Compresion failed")
      system("echo 'Mongodb database backup failed \n' | mail -s 'Mongodb database backup failed' #{node[:mail_id]}")
		end
else
  Chef::Log.warn("Backup failed")
  system("echo 'Mongodb database backup failed \n' | mail -s 'Mongodb database backup failed' #{node[:mail_id]}")
end
else
Chef::Log.warn("This is not backup layer")
end
