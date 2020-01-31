
# HOW TO DEPLOY
Run the `pipeline.sh` script as sudo.
Please ensure that the file `source.zip` is in the same folder
At the of the installation process, the WS should be up and running.
It uses a bunch of screen processes.

## JS code base

### Server-side

#### [Skeleton provider](https://github.com/glaunay/omega-topology-service)
Express-based MS providing skeleton json data
JSON skeleton file-cached, currently a single set of trim parameters is available. Hence, one cache exist at most.
Skeleton carries Homology Information, but no mitab supporting informations.

###### API
```
@url GET http://<µ-service-url>/tree/:specie-name
@response { SerializedOmegaTopology }
```

#### [Uniprot data provider](https://github.com/alkihis/omega-topology-uniprot)
Express-based MS providing uniprot OR GoTErms json data.

#### [MItab data provider](https://github.com/alkihis/omega-topology-mitab-socket)
Given a list of interaction pair, returns mitab arrays through socket-io socket.

#### MicroService depedency
##### [Edges data provider](https://github.com/alkihis/omegalomodb)
Express-based MS providing interactome edges json data.
This is a middleware service providing payload to "omega-topology-uniprot" "omega-topology-mitab-socket »

#### Software Library depedency
##### [JavaScript module](https://github.com/alkihis/omega-topology-fullstack)
Used as NPM package, provide omega topology library framework compatible w/ NodeJS or Browser runtimes

### Python code base

#### [MI Ontology](https://github.com/alkihis/omega-topology-MIontology)

**REST API** provides:

* a list of MI term information
* The minimal ontology tree embedding provided MI terms

#### [Taxonomic tree](https://github.com/alkihis/omega-topology-taxonomy)

##### REST API

Similar to above **REST API** provides:

* a list of ncbi taxonomic term information
* The minimal ontology tree embedding provided  ncbi taxonomic terms
