require 'chef'
passing = false
def checkPassing(data)
isArray = data.kind_of?(Array)
if isArray === false
  data = [data]
end
 data.each do |value|
         if value['passing'] == false
	  return false
	 end
 end
  return true
end

node[:stage_ghostscript_url].each do |url|
  rest = Chef::REST.new("#{url}")
  nodes = rest.get_rest("#{url}")
  data = nodes['data']
  passing = checkPassing(data)
  if passing == false
    break
  end
end


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

