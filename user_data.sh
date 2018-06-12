# update ubuntu and install dependencies
apt update && apt upgrade
apt install -y language-pack-en-base
LC_ALL=en_US.UTF-8 add-apt-repository ppa:ondrej/php -y
apt install -y zip unzip php7.0-xmlrpc php7.2-soap php7.0-cli php7.0 php7.0-fpm php7.0-mysql php7.0-zip php7.0-gd mcrypt php7.0-mcrypt php7.0-curl php7.0-json nginx git
apt install -y php7.0-mbstring php7.0-xml --force-yes

systemctl restart php7.0-fpm restart

# install composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer && chmod +x /usr/local/bin/composer

# remove distro files
mkdir -p /var/www/conduitapi.aws/

# download the application package and install
wget -qO- https://github.com/DonSanjeewa/conduit-ui/releases/download/v1.0.0/counduit-ui.tar.gz | tar xvz -C /var/www/conduitapi.aws/
cd /var/www/conduitapi.aws/ && composer install
# give permissions to nginx
chown www-data: -R /var/www/conduitapi.aws/

# create environment configuration
cd /var/www/conduitapi.aws/ && mv .env.example .env

cat<<EOFW >/etc/nginx/sites-available/conduitapi.aws
server {
    listen 80 default_server;

    server_name conduitapi.aws www.conduitapi.aws;

    access_log /srv/www/conduitapi.aws/logs/access.log;
    error_log /srv/www/conduitapi.aws/logs/error.log;

    root /var/www/conduitapi.aws/public;
    index index.php index.html;

    # serve static files directly
	location ~* \.(jpg|jpeg|gif|css|png|js|ico|html)$ {
		access_log off;
		expires max;
		log_not_found off;
	}

	# removes trailing slashes (prevents SEO duplicate content issues)
	if (!-d $request_filename)
	{
		rewrite ^/(.+)/$ /$1 permanent;
	}

	# enforce NO www
	if ($host ~* ^www\.(.*))
	{
		set $host_without_www $1;
		rewrite ^/(.*)$ $scheme://$host_without_www/$1 permanent;
	}

	# unless the request is for a valid file (image, js, css, etc.), send to bootstrap
	if (!-e $request_filename)
	{
		rewrite ^/(.*)$ /index.php?/$1 last;
		break;
	}

	location / {
		try_files $uri $uri/ /index.php?$query_string;
	}

	location ~* \.php$ {
        try_files $uri = 404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php7.0-fpm.sock; # may also be: 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
		deny all;
	}
}
EOFW
ln -s /etc/nginx/sites-available/conduitapi.aws /etc/nginx/sites-enabled/

systemctl restart nginx
