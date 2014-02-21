
require 'json'
require 'securerandom'
require 'sinatra'

JSON.create_id = nil

set :environment, :production
set :public_folder, File.expand_path('.')

class Host
  attr_reader :hostname, :passwords, :ip

  def initialize(hostname, ip)
    @hostname = hostname
    @ip = ip
    @passwords = {}
  end

  def random_password(name, hash = false)
    pass = @passwords[name] = gen_pass
    write_self_out
    hash ? crypt(pass) : pass
  end

  protected

  def crypt(str)
    str.crypt('$6$' + SecureRandom.random_number(36 ** 8).to_s(36))
  end

  def gen_pass(length = 32)
    character_set = [('a'..'z'), ('A'..'Z'), (0..9)].map(&:to_a).flatten.map(&:to_s)

    ambiguous_characters = %w{ O 0 l I 1 |}
    character_set.delete_if { |c| ambiguous_characters.include?(c) }

    length.times.map { character_set[rand(character_set.length)].to_s }.join
  end

  def write_self_out
    File.open("passwords/#{hostname}.json", 'w') do |f|
      f.write(JSON.pretty_generate({
        created: Time.now.strftime("%FT%T%:z"),
        hostname: hostname,
        ip: ip,
        passwords: passwords
      }))
    end
  end
end

unless File.exist?('escrow.pem')
  `echo -e "XX\n\n \n \n\n*\n\n" | openssl req -new -x509 -newkey rsa:4096 -keyout ./escrow.key -nodes -days 365 -out ./escrow.pem &> /dev/null`
  `chmod 0000 escrow.key`
end

get '/default-ks.cfg' do
  mac = request.env.to_h['HTTP_X_RHN_PROVISIONING_MAC_0']
  mac = mac.split[1].downcase.gsub(':', '') if mac

  os = (request.env.to_h['HTTP_X_ANACONDA_SYSTEM_RELEASE'] || 'unknown').downcase
  hostname = ([os, mac].join('-')) + '.cent.0x378.net'

  erb :kickstart, :locals => {host_data: Host.new(hostname, request.ip)}
end

put '/escrow_update' do
  return [400, "Missing required parameter."] unless params[:name] && params[:host]
  file_name = "./passwords/#{params[:host]}.json"
  return [404, "Host doesn't exist."] unless File.exists?(file_name)

  host = JSON.parse(File.read(file_name), symbolize_names: true)

  return [403, "Only host can update it's own record."] unless request.ip == host[:ip]

  host[:escrows] ||= {}
  host[:escrows][File.basename(params[:name])] = request.body.read

  content = JSON.pretty_generate(host)
  File.write(file_name, content)
  content
end

get '*' do
  path = File.join(settings.public_folder, URI.unescape(request.path))
  if File.directory?(path)
    Dir.foreach(path).map do |entry|
      File.directory?(File.join(path, entry)) ? "<a href='#{File.join(request.path, entry)}'>#{entry}</a><br/>" : "#{entry}<br/>"
    end.join("\n")
  elsif File.exist?(path)
    send_file(path)
  else
    not_found
  end
end

run Sinatra::Application

template :kickstart do
  <<-EOF
# version = Production

install
text

keyboard us
lang en_US.UTF-8
timezone --utc UTC
firstboot --disabled

logging --host=10.64.89.1 --port=514 --level=debug

url --url='http://10.64.89.1:3000/repo/centos/6.5/os/x86_64/'
repo --name='Local CentOS' --baseurl='http://10.64.89.1:3000/repo/centos/6.5/os/x86_64/' --cost='100'
repo --name='Local CentOS Updates' --baseurl='http://10.64.89.1:3000/repo/centos/6.5/updates/x86_64/' --cost='100'

network --onboot yes --device eth0 --bootproto dhcp --ipv6 auto --hostname='<%= host_data.hostname %>'
auth --enableshadow --passalgo='sha512'
selinux --enforcing
firewall --service='ssh'

rootpw  --iscrypted <%= host_data.random_password('root', true) %>
bootloader --location='mbr' --driveorder='vda' --append='crashkernel=auto console=ttyS0' --password='<%= host_data.random_password('bootloader', true) %>'

zerombr
ignoredisk --only-use='vda'
clearpart --all

# Primary partitions setup
part /boot    --size='500' --fstype='ext4'
part pv.31337 --size='1'   --grow --encrypted --cipher='aes-xts-plain64' --passphrase='<%= host_data.random_password('disk', false) %>' --escrowcert='http://10.64.89.1:3000/escrow.pem' --backuppassphrase

# Configure the volume group
volgroup vg_primary --pesize=4096 pv.31337

# And all the partitions within the volume group, minimum disk size is 10Gb,
# more is recommended.
logvol swap           --name=lv_swap   --vgname=vg_primary --size=1024
logvol /              --name=lv_root   --vgname=vg_primary --size=4096 --fstype=ext4
logvol /home          --name=lv_home   --vgname=vg_primary --size=1024 --fstype=ext4
logvol /tmp           --name=lv_tmp    --vgname=vg_primary --size=1024 --fstype=ext4
logvol /var/log/audit --name=lv_audit  --vgname=vg_primary --size=1024 --fstype=ext4
logvol /var/log       --name=lv_varlog --vgname=vg_primary --size=1024 --fstype=ext4
logvol /var           --name=lv_var    --vgname=vg_primary --size=1024 --fstype=ext4 --grow

reboot

%packages --nobase
@core
%end

%post --log=/root/ks-post.log
rm -f /etc/yum.repos.d/*

cat > /etc/yum.repos.d/local.repo << 'EOR'
[local-base]
name=Local CentOS-$releasever - Base
baseurl=http://10.64.89.1:3000/repo/centos/6.5/os/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6

[local-updates]
name=Local CentOS-$releasever - Updates
baseurl=http://10.64.89.1:3000/repo/centos/6.5/updates/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6

[local-extras]
name=Local CentOS-$releasever - Extras
baseurl=http://10.64.89.1:3000/repo/centos/6.5/extras/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6

[local-centosplus]
name=Local CentOS-$releasever - Plus
baseurl=http://10.64.89.1:3000/repo/centos/6.5/centosplus/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6

[local-contrib]
name=Local CentOS-$releasever - Contrib
baseurl=http://10.64.89.1:3000/repo/centos/6.5/contrib/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6

[local-elrepo]
name=Local ELRepo.org Community Enterprise Linux Repository - el6
baseurl=http://10.64.89.1:3000/repo/epel/6/$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
protect=0
EOR

for escrow_name in $(echo /root/*escrow*); do
  cat $escrow_name | base64 -w 0 | curl -X PUT -d @- 'http://10.64.89.1:3000/escrow_update?name='${escrow_name}'&host='$(hostname) &> /dev/null
done

%end
  EOF
end
