#!/bin/bash
# pipeline.sh

apt update
apt install vim sudo curl git unzip gnupg locales screen

locale-gen en_US.UTF-8
update-locale

export LC_CTYPE=en_US.UTF-8
export LANG=en_US.UTF-8


### AVANT DE DÉBUTER:
# Pousser via scp source.zip, 
# un zippage du dossier "source" de omega-topology-service (mitab et JSON)
# Le ZIP doit CONTENIR le dossier qui porte son nom, et pas seulement contenir son contenu

# Installation sources + paquets
echo "Setting up package repositories"
{
    curl -sL https://couchdb.apache.org/repo/bintray-pubkey.asc | sudo apt-key add - 
    echo "deb https://apache.bintray.com/couchdb-deb bionic main" | sudo tee -a /etc/apt/sources.list
    curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -

    sudo apt-get update
} > /dev/null

sudo apt-get install -y couchdb nodejs python3 python3-pip apache2 unzip

echo "" > /usr/sbin/policy-rc.d
sudo service couchdb start

rm -rf omega*

echo "Cloning Node-powered micro-services git repositories"

# Installing packages
for dir in "omega-topology-service" "omegalomodb" "omega-topology-uniprot" "omega-topology-mitab-socket"
do
    git clone --quiet "https://github.com/glaunay/$dir.git"
    cd $dir
    npm install --silent --no-progress
    cd ..
done

echo "Cloning website repository"

# Clonage du site web
git clone --quiet "https://github.com/glaunay/omega-topology.git" omega-topology-graph
cd omega-topology-graph
npm install --silent --no-progress &> /dev/null



echo "Building website"
# Build et déplacement de www dans dossier du dessus
npm run build
mv www ..
cd ..
# Déplacement dans le dossier apache classique
sudo mv www /var/www
sudo rm -rf /var/www/html 
sudo mv /var/www/www /var/www/html

echo "Unzipping interaction data"
{
    # Unzip les sources (mitab+JSON tree)
    cd omega-topology-service
    mkdir cache
    unzip ../source.zip
    cd ..
} > /dev/null

echo "Cloning Python-powered micro-services git repositories and creating virtual environnements"
{
    # Installation virtualenv
    mkdir ~/.envs

    sudo pip3 install virtualenv

    # Création des virtualenv et installation des paquets nécessaires
    for dir in "omega-topology-taxonomy" "omega-topology-MIontology"
    do
        virtualenv --python=/usr/bin/python3 ~/.envs/$dir
        git clone --quiet "https://github.com/glaunay/$dir.git" 
        source ~/.envs/$dir/bin/activate
        pip3 install flask owlready2 ete3 flask-cors
        deactivate
    done
} &> /dev/null


# Création de la base de données couch uniprot
curl -s -X PUT http://127.0.0.1:5984/uniprot > /dev/null

echo "Setting up Apache2 server"
{
    ## Forwarding: Nécessaire (n'utilise que le port 80)
    sudo a2enmod proxy
    sudo a2enmod ssl
    sudo a2enmod proxy
    sudo a2enmod proxy_balancer
    sudo a2enmod proxy_http
    sudo a2enmod proxy_wstunnel
    sudo a2enmod rewrite
    echo "<VirtualHost *:80>
            ServerAdmin webmaster@localhost
            DocumentRoot /var/www/html

            ErrorLog \${APACHE_LOG_DIR}/error.log
            CustomLog \${APACHE_LOG_DIR}/access.log combined

            RewriteEngine On

            RewriteCond %{REQUEST_URI} ^/specie
            RewriteRule ^/specie/(.*)$ /?specie=\$1 [R]

            # socket.io 1.0+ starts all connections with an HTTP polling request
            RewriteCond %{QUERY_STRING} transport=polling       [NC]
            RewriteRule /(.*)           http://localhost:3456/\$1 [P]

            # When socket.io wants to initiate a WebSocket connection, it sends an
            # \"upgrade: websocket\" request that should be transferred to ws://
            RewriteCond %{HTTP:Upgrade} websocket               [NC]
            RewriteRule /(.*)           ws://localhost:3456/\$1  [P]

            # Redirections HTTP classiques
            ProxyPass /service http://localhost:3455
            ProxyPass /uniprot http://localhost:3289
            ProxyPass /taxonomy http://localhost:3278
            ProxyPass /ontology http://localhost:3279
    </VirtualHost>" > 000-default.conf

    sudo rm /etc/apache2/sites-available/000-default.conf 
    sudo mv 000-default.conf /etc/apache2/sites-available/

    sudo service apache2 restart
} > /dev/null

## Lancer omegalomodb en tâche de fond
cd omegalomodb
screen -S omegalomodb -dm node build/index.js
cd ..

echo "Setting up CouchDB with MI Tab data, this may take a while"
echo ""
echo ">--------"
## Initialiser le MI Tab
cd omega-topology-service
node --max-old-space-size=8192 build/cli.js -r all -n
cd ..
echo ">--------"

echo "Setting up complete."

echo ""
echo "Starting micro-services"
## Lancement des services dans des screens
dir="omega-topology-service"
cd $dir
screen -S $dir -dm node build/cli.js
cd ..

dir="omega-topology-uniprot"
cd $dir
screen -S $dir -dm node build/index.js -c http://localhost:5984 -d http://localhost:3280 -m couch
cd ..

dir="omega-topology-mitab-socket"
cd $dir
screen -S $dir -dm node build/index.js
cd ..

echo "Building NCBI taxonomy database for taxonomy service, this may take a while"
{
    ## Initialise la base de données NCBI
    dir="omega-topology-taxonomy" 
    cd $dir
    source ~/.envs/$dir/bin/activate
    echo "from ete3 import NCBITaxa
ncbi = NCBITaxa()
ncbi.update_taxonomy_database()" > init.py
    python init.py
    rm init.py
    deactivate
} > /dev/null

# Lance le serveur Flask
screen -S $dir -dm bash -c "source ./start.sh"
cd ..

# Lance MI flask
dir="omega-topology-MIontology"
cd $dir
screen -S $dir -dm bash -c "source ./start.sh"
cd ..

echo "Setting up complete."
echo "Micro-services are started into screens. Enter 'screen -list' to see them."


