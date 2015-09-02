require 'chef'
passing = false
node[:stage_ghostscript_url].each do |url|
rest = Chef::REST.new("#{url}")
nodes = rest.get_rest("#{url}")
data = nodes['data']
passing = checkPassing(data)
  if passing == false
    break
  end
end
def checkPassing(data)
 data.each do |value|
         if value['passing'] == false
         return false
      end
  end
  return true

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

