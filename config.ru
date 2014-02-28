
require 'fileutils'
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
    file_name = File.expand_path("./passwords/#{hostname}.json")

    File.open(file_name, 'w') do |f|
      f.write(JSON.pretty_generate({
        created: Time.now.strftime("%FT%T%:z"),
        hostname: hostname,
        ip: ip,
        passwords: passwords
      }))
    end

    FileUtils.ln_s(file_name, "passwords/latest.json", :force => true)
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

  if File.exists?("./hosts/#{mac}.json")
    content = JSON.parse(File.read("./hosts/#{mac}.json"))
    hostname = "#{content[:hostname]}.cent.0x378.net"
  else
    hostname = ([os, mac].join('-')) + '.cent.0x378.net'
  end

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

post '/register' do
  return [400, "Missing required parameter"] unless params[:mac] && params[:hostname]

  content = {
    ip: request.ip,
    hostname: params[:hostname],
    mac: params[:mac].downcase.gsub(':', '')
  }

  File.write("./hosts/#{content[:mac]}.json", JSON.pretty_generate(content))
  [200, "Wrote out host"]
end

get '*' do
  return [403, "Nice try."] if request.path =~ /\/passwords/

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
exclude=postgresql*

[local-updates]
name=Local CentOS-$releasever - Updates
baseurl=http://10.64.89.1:3000/repo/centos/6.5/updates/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
exclude=postgresql*

[local-extras]
name=Local CentOS-$releasever - Extras
baseurl=http://10.64.89.1:3000/repo/centos/6.5/extras/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
exclude=postgresql*

[local-centosplus]
name=Local CentOS-$releasever - Plus
baseurl=http://10.64.89.1:3000/repo/centos/6.5/centosplus/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
exclude=postgresql*

[local-contrib]
name=Local CentOS-$releasever - Contrib
baseurl=http://10.64.89.1:3000/repo/centos/6.5/contrib/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
exclude=postgresql*

[local-elrepo]
name=Local ELRepo.org Community Enterprise Linux Repository - el6
baseurl=http://10.64.89.1:3000/repo/epel/6/$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
protect=0
exclude=postgresql*

[local-puppetlabs-products]
name=Local Puppet Labs Products El 6 - $basearch
baseurl=http://10.64.89.1:3000/repo/puppet/yum/el/6/products/$basearch
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs
enabled=1
gpgcheck=1
exclude=postgresql*

[local-puppetlabs-deps]
name=Local Puppet Labs Dependencies El 6 - $basearch
baseurl=http://10.64.89.1:3000/repo/puppet/yum/el/6/dependencies/$basearch
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs
enabled=1
gpgcheck=1
exclude=postgresql*

[local-pgdg93]
name=Local PostgreSQL 9.3 $releasever - $basearch
baseurl=http://10.64.89.1:3000/repo/postgresql/9.3/redhat/rhel-$releasever-$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-PGDG-93
EOR

rpm --import http://10.64.89.1:3000/RPM-GPG-KEY-PGDG-93
rpm --import http://10.64.89.1:3000/RPM-GPG-KEY-elrepo.org
rpm --import http://10.64.89.1:3000/RPM-GPG-KEY-puppetlabs

for escrow_name in $(echo /root/*escrow*); do
  cat $escrow_name | base64 -w 0 | curl -X PUT -d @- 'http://10.64.89.1:3000/escrow_update?name='${escrow_name}'&host='$(hostname) &> /dev/null
  if [ $? ]; then
    rm -f $escrow_name
  fi
done

mkdir -p /root/.ssh/
chmod 0700 /root/.ssh
chown root:root /root/.ssh
cat > /root/.ssh/authorized_keys << EOK
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDXUDvlxSdKo7ZkdQGnAeccgSeb+/VnMxI9Nj0gVpjckyaWI8rPOI8CeMVwz4yi6RCmyCovwVY2kNwp6DVql/fqv9WTMl75Ckpq89Y96VfO3btzw4ktJhGWWXdlZO8UcfMqNgWGBLF3KeFJe1Kzkf8OOxugC86AJzXbPLvXiJ3JYh6RgnW2DThzLEo+WdV6oI0IwFKMKXx4IKuC3HhGs9T1xuTVUoUEuxl3aIxDDmeValtPKHxEkMx02oVBR9l0QF958ehtk9/ir9mqSpvc0aHxs+xdWE35R39D649elRlnYyZxx/Hb/9Pb76mtI9mYtcOBB39g3kjv0QqJUJdNjgfHfFTdTY0w7JHaLDT3MubNwvW2cFfdxy0gI8Ucfxi4io+zgUP2UEnTax4uXbyXcy2L6W1TFP4lK8akhDkYe9sFSpcCkZfT68c8SQCDit20Mml9bpCkJg4AX2/OMc7vVvsdcfF/5MZdrZQXbdzi8M3V/YoB293mWpu/IL+BjdWgwF3MhQfO8oTZXjBXkaVKufNnoF1chKO4xzXMoA45wOfl6GD1ErLXs7mFsIg2Ulsc7RlAnQuP8QcPACZ2Gu7o7TcFO3HvhjrK9wqjLyK1sgqATwn8Uo/zTkVLmMWpMKXgsNVqRVfAhyDat0ASSI7b/daDMr31U+T/xDTByfAXyGj1+Q==
ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBKNN3/CwifgmhtiXwl49+ToWWSDRL+R+/0c74FFuVnbWnU+d3XmDvUK/Ib/vS4r2hKSvLFe1Gr0uWzsSbC/lOY0=
EOK
chmod 0600 /root/.ssh/authorized_keys
chown root:root /root/.ssh/authorized_keys

%end
  EOF
end
