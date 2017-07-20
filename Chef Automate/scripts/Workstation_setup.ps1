param(
[string] $adminUsername = "$1",
[string] $adminPassword = "$2",
[string] $ChefAutoFqdn = "$3",
[string] $orguser= "$4"
)
Invoke-WebRequest -Uri https://aztdrepo.blob.core.windows.net/chefautomate-testdrive/putty-64bit-0.70-installer.msi -OutFile c:/users/Putty.msi 
Start-Process c:/Users/Putty.msi   /qn -Wait
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned  -Force
cd C:\opscode\chefdk\bin
chef generate app c:\Users\chef-repo
git clone https://github.com/sysgain/ChefAutomate-Cookbooks.git c:/Users/cookbookstore
echo c:\Users\chef-repo\.chef\knife.rb | knife configure --server-url https://$ChefAutoFqdn/organizations/$orguser --validation-client-name $orguser-validator --validation-key c:/Users/chef-repo/.chef/$orguser-validator.pem --user $adminUsername --repository c:/Users/chef-repo
echo n | & "C:\Program Files\PuTTY\pscp.exe"  -scp -pw $adminPassword ${adminUsername}@${ChefAutoFqdn}:/etc/opscode/$adminUsername".pem" C:\Users\chef-repo\.chef\$adminUsername".pem"
echo n | & "C:\Program Files\PuTTY\pscp.exe"  -scp -pw $adminPassword ${adminUsername}@${ChefAutoFqdn}:/etc/opscode/$orguser-validator.pem C:\Users\chef-repo\.chef\$orguser-validator.pem
cp -r C:\Users\cookbookstore\* C:\Users\chef-repo\cookbooks
mv C:\Users\chef-repo\cookbooks\roles C:\Users\chef-repo
cd C:\opscode\chefdk\bin\
knife ssl  fetch --config c:\Users\chef-repo\.chef\knife.rb  --server-url https://$ChefAutoFqdn/organizations/$orguser
knife bootstrap windows winrm localhost --config c:\Users\chef-repo\.chef\knife.rb -x $adminUsername -P $adminPassword -N chefnode0
chef-client 
knife cookbook upload --config c:\Users\chef-repo\.chef\knife.rb --server-url https://$ChefAutoFqdn/organizations/$orguser compat_resource audit
knife cookbook upload --config c:\Users\chef-repo\.chef\knife.rb --server-url https://$ChefAutoFqdn/organizations/$orguser ohai windows tissues
knife cookbook upload --config c:\Users\chef-repo\.chef\knife.rb --server-url https://$ChefAutoFqdn/organizations/$orguser logrotate cron chef-client

knife role from file c:\users\chef-repo\roles\auditrun.json --config c:\Users\chef-repo\.chef\knife.rb --server-url https://$ChefAutoFqdn/organizations/$orguser
knife node run_list set chefnode0 "role[auditrun]" --config c:\Users\chef-repo\.chef\knife.rb --server-url https://$ChefAutoFqdn/organizations/$orguser
#knife node run_list add --config c:\Users\chef-repo\.chef\knife.rb --server-url https://$ChefAutoFqdn/organizations/$orguser chefnode0 recipe[audit]
chef-client
