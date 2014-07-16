
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
  hostname = [(params[:hostname] || mac), os, '0x378.net'].join('.')

  erb :min_base, :locals => {host_data: Host.new(hostname, request.ip)}
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

template :secure_base do
  File.read('secure_base.cfg')
end

template :min_base do
  File.read('min_base.cfg')
end

