service couchdb start
service apache2 start

unset http_proxy
unset HTTP_PROXY
unset HTTPS_PROXY
unset https_proxy

PROXY=""
function usage() {
    cat <<EOF
Run back-end microservice as detached screen
Usage: source start_screen.sh [-x PROXY]
    -x|--proxy)  Host proxy adress
    -h|--help)  Show this help
EOF
}

while [[ $# -ge 1 ]]
do
key="$1"
case $key in
    -x|--proxy)
    PROXY="$2"
    shift # past argument
    ;;
    -h|--help)
    usage;exit;
    ;;
esac
shift # past argument or value
done

## Lancer omegalomodb en tâche de fond
cd omegalomodb
screen -S omegalomodb -dm node build/index.js
cd ..


echo ""
echo "Starting micro-services"
## Lancement des services dans des screens
dir="omega-topology-service"
cd $dir
screen -S $dir -dm node build/cli.js
cd ..

dir="omega-topology-uniprot"
ms_flag=""
[[ ! -z "$PROXY" ]] && ms_flag=" -x $PROXY "

cd $dir
screen -S $dir -dm node build/index.js -c http://localhost:5984 -d http://localhost:3280 -m couch $ms_flag
cd ..

dir="omega-topology-mitab-socket"
cd $dir
screen -S $dir -dm node build/index.js
cd ..

cd omega-topology-taxonomy
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
