require 'chef'

rest = Chef::REST.new("#{node[:stage_ghostscript_url]}")
nodes = rest.get_rest("#{node[:stage_ghostscript_url]}")
data = nodes['data']
def checkPassing(data)
 data.each do |value|
         if value['passing'] == false
         return false
      end
  end
  return true
end
passing = checkPassing(data)

if "#{node[:ignore_failed_tests]}" == 'true'
Chef::Log.info("Testing")
if passing == false
Chef::Log.info("Success")
end
else
if passing == true
Chef::Log.info("Success")
else
 Chef::Application.fatal!("failed")
end
end
