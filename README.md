# BOSH Release for go-graphite

The aim of this bosh release is to deploy a go-graphite cluster consisting of the following components:

* carbon-c-relay
* go-carbon / carbonserver
* carbonzipper / carbonapi

## Disclaimer

This is not presently a production ready go-graphite BOSH release. This is a work in progress. It is suitable for experimentation and may not become supported in the future.

## Usage

To use this bosh release, first upload it to your bosh:

```
bosh target BOSH_HOST
git clone https://github.com/SpringerPE/go-graphite-boshrelease.git
cd go-graphite-boshrelease
bosh create release && bosh upload release
```

For [bosh-lite](https://github.com/cloudfoundry/bosh-lite), you can quickly create a deployment manifest & deploy a cluster:

```
templates/make_manifest warden
bosh -n deploy
```

For Openstack:

```
templates/make_manifest openstack
bosh -n deploy
```


For AWS EC2:

NOT YET IMPLEMENTED

### Development

As a developer of this release, create new releases and upload them:

```
# Prepare the golang packages resolving their dependencies beforehand
./bosh_prepare
bosh create release --force && bosh -n upload release
```

### Final releases

To share final releases:

```
bosh create release --final
```

By default the version number will be bumped to the next major number. You can specify alternate versions:


```
bosh create release --final --version 2.1
```

After the first release you need to contact [Dmitriy Kalinin](mailto://dkalinin@pivotal.io) to request your project is added to https://bosh.io/releases (as mentioned in README above).
